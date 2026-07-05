import jsAudio from 'libjsaudioengine.so';
import { http } from '@kit.NetworkKit';
import { socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'AudioEngine';

/**
 * Event payload from the Native C++ JSVM engine.
 */
interface JsvmEvent {
  action: string;
  data: string;
}

/**
 * HTTP request options from script.
 */
interface JsvmHttpOptions {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  form?: string;
  timeout?: number;
}

/**
 * ArkTS wrapper for the Native C++ JSVM audio source engine.
 *
 * Architecture (matching LX Music Mobile):
 *   JSVM (C++) <── registerCallback / sendToJs ──> ArkTS (this file)
 *
 * Event flow:
 *   Script → __lx_native_call__ → NativeActionCallback → ArkTS handleEvent()
 *   ArkTS → sendToJs() → __lx_native__ → jsCall() in preload script
 */
export class AudioEngine {
  private static instance: AudioEngine | undefined = undefined;
  private engineReady: boolean = false;
  private scriptInited: boolean = false;
  private capability: Record<string, Object> | null = null;
  private initResolve: ((ok: boolean) => void) | null = null;
  private execVersion: number = 0;
  private pendingRequests: Map<string, (resp: Object | null) => void> = new Map();
  private requestListener: ((event: Object) => void) | null = null;
  // HTTP cache: url → cached JSON response payload (avoids re-fetching init.conf etc.)
  private httpCache: Map<string, string> = new Map();
  // Retry tracking per requestKey for 429 backoff
  private httpRetryMap: Map<string, number> = new Map();

  public static getInstance(): AudioEngine {
    if (!AudioEngine.instance) {
      AudioEngine.instance = new AudioEngine();
    }
    return AudioEngine.instance;
  }

  public async init(): Promise<void> {
    if (this.engineReady) {
      return;
    }
    try {
      jsAudio.createEngine();
      console.info(`${TAG}: JSVM engine created`);

      jsAudio.registerCallback((event: JsvmEvent) => {
        this.handleNativeEvent(event);
      });
      console.info(`${TAG}: Native event callback registered`);

      this.engineReady = true;
    } catch (e) {
      console.error(`${TAG}: init failed: ${JSON.stringify(e)}`);
      throw new Error(`AudioEngine init failed: ${JSON.stringify(e)}`);
    }
  }

  public async executeScript(scriptContent: string, scriptId: string): Promise<boolean> {
    if (!this.engineReady) {
      await this.init();
    }

    const version: number = ++this.execVersion;

    return new Promise<boolean>((resolve) => {
      this.scriptInited = false;
      this.capability = null;
      this.initResolve = resolve;

      try {
        const ok: boolean = jsAudio.executeScript(scriptContent, scriptId);
        if (!ok) {
          console.error(`${TAG}: executeScript failed for ${scriptId}`);
          this.initResolve = null;
          resolve(false);
          return;
        }

        console.info(`${TAG}: executeScript ok for ${scriptId} (ver=${version}), waiting for init...`);

        setTimeout(() => {
          if (this.initResolve && version === this.execVersion) {
            console.warn(`${TAG}: init timeout for ${scriptId} (ver=${version})`);
            this.initResolve(false);
            this.initResolve = null;
          }
        }, 120000);

      } catch (e) {
        console.error(`${TAG}: executeScript error: ${JSON.stringify(e)}`);
        this.initResolve = null;
        resolve(false);
      }
    });
  }

  public setRequestListener(listener: ((event: Object) => void) | null): void {
    this.requestListener = listener;
  }

  public async sendRequestToScript(source: string, action: string, info: object): Promise<Object | null> {
    if (!this.engineReady || !this.scriptInited) {
      console.warn(`${TAG}: Engine not ready for request`);
      return null;
    }

    const requestKey = `req_${Date.now()}_r${Math.floor(Math.random() * 99999)}`;
    const inner: Record<string, Object> = {};
    inner['source'] = source;
    inner['action'] = action;
    inner['info'] = info as Object;
    const requestPayload: Record<string, Object> = {
      'requestKey': requestKey,
      'data': inner
    };
    console.info(`${TAG}: sendRequestToScript payload: ${JSON.stringify(requestPayload)}`);

    return new Promise<Object | null>((resolve) => {
      this.pendingRequests.set(requestKey, (result: Object | null) => {
        resolve(result);
      });

      try {
        jsAudio.sendToJs('request', JSON.stringify(requestPayload));
      } catch (e) {
        console.error(`${TAG}: sendRequestToScript error: ${JSON.stringify(e)}`);
        this.pendingRequests.delete(requestKey);
        resolve(null);
      }

      setTimeout(() => {
        if (this.pendingRequests.has(requestKey)) {
          console.warn(`${TAG}: request timeout: ${requestKey}`);
          this.pendingRequests.delete(requestKey);
          resolve(null);
        }
      }, 30000);
    });
  }

  private handleNativeEvent(event: JsvmEvent): void {
    console.info(`${TAG}: native event: ${event.action}`);

    switch (event.action) {
      case 'init':
        this.handleScriptInit(event.data);
        break;
      case 'request':
        this.handleHttpRequest(event.data);
        break;
      case 'cancelRequest':
        break;
      case 'response':
        this.handleScriptResponse(event.data);
        break;
      case 'showUpdateAlert':
        this.handleUpdateAlert(event.data);
        break;
      default:
        console.warn(`${TAG}: unknown native event: ${event.action}`);
    }
  }

  private handleScriptInit(dataStr: string): void {
    try {
      const parsed: Record<string, Object> = JSON.parse(dataStr) as Record<string, Object>;
      console.info(`${TAG}: script init: status=${parsed['status']}`);

      if (parsed['status'] === true) {
        const info = parsed['info'] as Record<string, Object>;
        if (info && info['sources']) {
          this.capability = info['sources'] as Record<string, Object>;
          console.info(`${TAG}: capability sources: ${JSON.stringify(Object.keys(this.capability))}`);
        }
        this.scriptInited = true;
        if (this.initResolve) {
          this.initResolve(true);
          this.initResolve = null;
        }
      } else {
        console.warn(`${TAG}: script init failed: ${parsed['errorMessage']}`);
        if (this.initResolve) {
          this.initResolve(false);
          this.initResolve = null;
        }
      }
    } catch (e) {
      console.error(`${TAG}: handleScriptInit parse error: ${JSON.stringify(e)}`);
      if (this.initResolve) {
        this.initResolve(false);
        this.initResolve = null;
      }
    }
  }

  private handleHttpRequest(dataStr: string): void {
    try {
      const parsed: Record<string, Object> = JSON.parse(dataStr) as Record<string, Object>;
      const requestKey: string = parsed['requestKey'] as string;
      const url: string = parsed['url'] as string;
      const options: Record<string, Object> = (parsed['options'] as Record<string, Object>) || ({} as Record<string, Object>);

      console.info(`${TAG}: HTTP request: ${requestKey} → ${url}`);
      const methodStr: string = (options['method'] as string) || 'GET';
      const headers: Record<string, string> = (options['headers'] as Record<string, string>) || {};
      if (!headers['User-Agent']) {
        headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36';
      }

      console.info(`${TAG}: HTTP headers: ${JSON.stringify(headers)}`);
      console.info(`${TAG}: HTTP url: ${url}`);
      const timeout: number = (typeof options['timeout'] === 'number' && (options['timeout'] as number) > 0)
        ? (options['timeout'] as number) : 15000;
      const body: string = (options['body'] as string) || '';

      // Only cache GET requests (e.g. init.conf) — POST requests (musicUrl) have unique bodies
      const isGet: boolean = methodStr.toUpperCase() === 'GET';
      if (isGet && this.httpCache.has(url)) {
        console.info(`${TAG}: HTTP cache hit: ${requestKey} → ${url}`);
        jsAudio.sendToJs('response', this.httpCache.get(url)!);
        return;
      }

      // Initialize retry count for this request (max 6 retries: 1s/2s/4s/8s/16s/32s)
      this.httpRetryMap.set(requestKey, 6);

      // For HTTP (non-TLS) requests, use raw TCP socket to ensure origin-form request line
      if (url.startsWith('http://')) {
        this.rawHttpRequest(requestKey, url, methodStr, headers, body, timeout);
      } else {
        this.moduleHttpRequest(requestKey, url, methodStr, headers, body, timeout);
      }
    } catch (e) {
      console.error(`${TAG}: handleHttpRequest parse error: ${JSON.stringify(e)}`);
    }
  }

  /**
   * Shared response handler with retry + cache support.
   * - Caches 200 responses so subsequent requests skip the network
   * - Retries 429 (Cloudflare rate-limit) with exponential backoff
   */
  private handleHttpResponse(
    requestKey: string, url: string, methodStr: string,
    headers: Record<string, string>, body: string, timeout: number,
    statusCode: number, respHeaders: Record<string, string>, respBody: string
  ): void {
    let responsePayload: Record<string, Object | null> = {};
    responsePayload['requestKey'] = requestKey;
    responsePayload['error'] = null;
    let respObj: Record<string, Object> = {};
    respObj['statusCode'] = statusCode;
    respObj['statusMessage'] = statusCode === 200 ? 'OK' : `HTTP ${statusCode}`;
    respObj['headers'] = respHeaders;
    respObj['body'] = respBody;
    respObj['url'] = url;
    respObj['ok'] = statusCode >= 200 && statusCode < 300;
    responsePayload['response'] = respObj;

    const payloadStr: string = JSON.stringify(responsePayload) as string;

    // Retry on 429 (Cloudflare rate-limit) with exponential backoff
    if (statusCode === 429) {
      const retries: number = this.httpRetryMap.get(requestKey) ?? 0;
      if (retries > 0) {
        this.httpRetryMap.set(requestKey, retries - 1);
        const delay: number = Math.pow(2, 6 - retries) * 1000; // 1s, 2s, 4s, 8s, 16s, 32s
        console.warn(`${TAG}: HTTP 429, retrying in ${delay}ms (${retries - 1} left): ${url}`);
        const isHttps: boolean = !url.startsWith('http://');
        setTimeout(() => {
          if (isHttps) {
            this.moduleHttpRequest(requestKey, url, methodStr, headers, body, timeout);
          } else {
            this.rawHttpRequest(requestKey, url, methodStr, headers, body, timeout);
          }
        }, delay);
        return;
      }
    }

    // Only cache GET 200 responses (init.conf etc.), not POST (musicUrl)
    if (statusCode === 200 && methodStr.toUpperCase() === 'GET') {
      this.httpCache.set(url, payloadStr);
    }

    this.httpRetryMap.delete(requestKey);
    const ret = jsAudio.sendToJs('response', payloadStr) as string;
    console.info(`${TAG}: HTTP response: ${requestKey} → ${statusCode}, bodyLen=${respBody.length}, sendToJsRet=${ret}`);
  }

  /**
   * Use raw TCP socket for HTTP requests to send origin-form request line:
   *   GET /path HTTP/1.1\r\nHost: host\r\n...
   * instead of absolute-form which some nginx configs reject.
   */
  private async rawHttpRequest(
    requestKey: string, url: string, methodStr: string,
    headers: Record<string, string>, body: string, timeout: number
  ): Promise<void> {
    const urlMatch = url.match(/^http:\/\/([^\/:]+)(?::(\d+))?(\/.*)$/);
    if (!urlMatch) {
      this.failRequest(requestKey, 'Invalid HTTP URL: ' + url);
      return;
    }
    const host: string = urlMatch[1];
    const port: number = urlMatch[2] ? parseInt(urlMatch[2]) : 80;
    const path: string = urlMatch[3];

    // Build raw HTTP/1.1 request in origin-form
    let rawReq = `${methodStr.toUpperCase()} ${path} HTTP/1.1\r\n`;
    rawReq += `Host: ${host}\r\n`;
    for (const key of Object.keys(headers)) {
      rawReq += `${key}: ${headers[key]}\r\n`;
    }
    if (body.length > 0) {
      rawReq += `Content-Length: ${body.length}\r\n`;
    }
    rawReq += `Connection: close\r\n\r\n`;
    if (body.length > 0) {
      rawReq += body;
    }

    console.info(`${TAG}: Raw HTTP → ${host}:${port}${path}`);

    let tcp: socket.TCPSocket | null = null;
    let responseData = '';
    let resolved = false;

    const cleanup = () => {
      if (tcp) {
        try { tcp.close(); } catch (_) { /* ignore */ }
      }
    };

    const resolveResult = (statusCode: number, statusMessage: string,
                            respHeaders: Record<string, string>, respBody: string) => {
      if (resolved) return;
      resolved = true;
      cleanup();
      if (statusCode !== 200) {
        console.info(`${TAG}: Raw HTTP response body: ${respBody.substring(0, 500)}`);
      }
      this.handleHttpResponse(requestKey, url, methodStr, headers, body, timeout,
                               statusCode, respHeaders, respBody);
    };

    const fail = (errMsg: string) => {
      if (resolved) return;
      resolved = true;
      cleanup();
      this.failRequest(requestKey, errMsg);
    };

    try {
      tcp = socket.constructTCPSocketInstance();

      await tcp.connect({
        address: { address: host, port: port, family: 1 },
        timeout: timeout
      });

      const encoder = new util.TextEncoder();
      const encoded = encoder.encodeInto(rawReq);
      await tcp.send({ data: encoded.buffer as ArrayBuffer });

      tcp.on('message', (value: socket.SocketMessageInfo) => {
        const decoder = new util.TextDecoder('utf-8');
        const chunk: string = decoder.decodeWithStream(new Uint8Array(value.message), { stream: true });
        responseData += chunk;
      });

      tcp.on('close', () => {
        if (!resolved && responseData.length > 0) {
          this.parseRawHttpResponse(responseData, resolveResult, fail, requestKey);
        }
      });

      tcp.on('error', (err: BusinessError) => {
        fail(`TCP error: ${err.message}`);
      });

      // Timeout
      setTimeout(() => {
        if (!resolved && responseData.length > 0) {
          this.parseRawHttpResponse(responseData, resolveResult, fail, requestKey);
        } else if (!resolved) {
          fail('TCP timeout');
        }
      }, timeout);

    } catch (e) {
      fail(`TCP connect failed: ${JSON.stringify(e)}`);
    }
  }

  private parseRawHttpResponse(
    raw: string,
    resolveResult: (code: number, msg: string, headers: Record<string, string>, body: string) => void,
    fail: (msg: string) => void,
    requestKey: string
  ): void {
    try {
      const headerEnd = raw.indexOf('\r\n\r\n');
      if (headerEnd < 0) {
        fail('Invalid HTTP response: no header end');
        return;
      }
      const headerPart = raw.substring(0, headerEnd);
      const body = raw.substring(headerEnd + 4);

      const lines = headerPart.split('\r\n');
      if (lines.length < 1) {
        fail('Empty HTTP response');
        return;
      }

      // Parse status line: "HTTP/x.x 200 OK"
      const statusLine = lines[0];
      const statusMatch = statusLine.match(/^HTTP\/\d\.\d\s+(\d+)\s+(.*)$/);
      if (!statusMatch) {
        fail('Invalid status line: ' + statusLine);
        return;
      }
      const statusCode = parseInt(statusMatch[1]);
      const statusMessage = statusMatch[2];

      // Parse headers
      const respHeaders: Record<string, string> = {};
      for (let i = 1; i < lines.length; i++) {
        const colonIdx = lines[i].indexOf(':');
        if (colonIdx > 0) {
          const key = lines[i].substring(0, colonIdx).trim();
          const value = lines[i].substring(colonIdx + 1).trim();
          respHeaders[key.toLowerCase()] = value;
        }
      }

      resolveResult(statusCode, statusMessage, respHeaders, body);
    } catch (e) {
      fail('HTTP parse error: ' + JSON.stringify(e));
    }
  }

  private failRequest(requestKey: string, errMsg: string): void {
    let errorPayload: Record<string, Object | null> = {};
    errorPayload['requestKey'] = requestKey;
    errorPayload['error'] = errMsg;
    errorPayload['response'] = null;
    try {
      jsAudio.sendToJs('response', JSON.stringify(errorPayload));
    } catch (e) {
      console.error(`${TAG}: sendToJs error: ${JSON.stringify(e)}`);
    }
    console.warn(`${TAG}: HTTP error: ${requestKey} → ${errMsg}`);
  }

  /**
   * Use HarmonyOS http module for HTTPS requests (npm registry etc.).
   */
  private moduleHttpRequest(
    requestKey: string, url: string, methodStr: string,
    headers: Record<string, string>, body: string, timeout: number
  ): void {
    const httpRequest = http.createHttp();

    const requestOptions: http.HttpRequestOptions = {
      method: methodStr.toUpperCase() === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
      header: headers,
      extraData: body || undefined,
      connectTimeout: timeout,
      readTimeout: timeout
    };

    httpRequest.request(url, requestOptions).then((resp: http.HttpResponse) => {
      httpRequest.destroy();

      const respBodyStr: string = (resp.result as string || '');
      const respHeaders: Record<string, string> = (resp.header as Record<string, string>) || ({} as Record<string, string>);
      if (resp.responseCode !== 200 || respBodyStr.length < 200) {
        console.info(`${TAG}: HTTP response headers: ${JSON.stringify(resp.header)}`);
      }
      this.handleHttpResponse(requestKey, url, methodStr, headers, body, timeout,
                               resp.responseCode, respHeaders, respBodyStr);

    }).catch((err: Error) => {
      httpRequest.destroy();
      this.failRequest(requestKey, err.message || 'network error');
    });
  }

  private handleScriptResponse(dataStr: string): void {
    try {
      const parsed: Record<string, Object> = JSON.parse(dataStr) as Record<string, Object>;
      const requestKey: string = parsed['requestKey'] as string;
      const status: boolean = parsed['status'] as boolean;
      const result: Object | undefined = parsed['result'];
      const errorMessage: Object | undefined = parsed['errorMessage'];

      console.info(`${TAG}: script response: key=${requestKey} status=${status} resultType=${typeof result} errMsg=${errorMessage}`);
      if (result) {
        console.info(`${TAG}: result keys: ${JSON.stringify(Object.keys(result as Record<string, Object>))}`);
      }

      console.info(`${TAG}: script response: ${requestKey} status=${status}`);

      const rsv = this.pendingRequests.get(requestKey);
      if (rsv) {
        this.pendingRequests.delete(requestKey);
        if (status && result) {
          rsv(result);
        } else {
          console.warn(`${TAG}: script response error: ${parsed['errorMessage']}`);
          rsv(null);
        }
      }
    } catch (e) {
      console.error(`${TAG}: handleScriptResponse parse error: ${JSON.stringify(e)}`);
    }
  }

  private handleUpdateAlert(dataStr: string): void {
    try {
      const parsed: Record<string, Object> = JSON.parse(dataStr) as Record<string, Object>;
      console.info(`${TAG}: update alert: ${parsed['log']} url=${parsed['updateUrl']}`);
    } catch (e) {
      console.error(`${TAG}: handleUpdateAlert parse error: ${JSON.stringify(e)}`);
    }
  }

  public async callFunction(functionName: string, params: string): Promise<string> {
    if (!this.engineReady) {
      throw new Error('Engine not initialized');
    }
    try {
      return jsAudio.callFunction(functionName, params) as string;
    } catch (e) {
      console.error(`${TAG}: callFunction error: ${JSON.stringify(e)}`);
      throw new Error(`callFunction ${functionName} error: ${JSON.stringify(e)}`);
    }
  }

  public async release(): Promise<void> {
    if (!this.engineReady) {
      return;
    }
    try {
      jsAudio.releaseEngine();
      this.engineReady = false;
      this.scriptInited = false;
      this.capability = null;
      this.initResolve = null;
      this.pendingRequests.clear();
    } catch (e) {
      console.error(`${TAG}: release error: ${JSON.stringify(e)}`);
    }
  }

  /**
   * Reset the engine: release old JSVM and create a fresh one.
   * Use when switching audio source scripts to avoid state conflicts.
   */
  public async reset(): Promise<void> {
    if (this.engineReady) {
      try {
        jsAudio.releaseEngine();
      } catch (e) {
        console.warn(`${TAG}: releaseDuringReset error: ${JSON.stringify(e)}`);
      }
      this.engineReady = false;
    }
    this.scriptInited = false;
    this.capability = null;
    this.initResolve = null;
    this.pendingRequests.clear();
    this.execVersion = 0;
    await this.init();
  }

  public isReady(): boolean {
    return this.engineReady;
  }

  public isScriptInited(): boolean {
    return this.scriptInited;
  }

  public getCapability(): Record<string, Object> | null {
    return this.capability;
  }
}
