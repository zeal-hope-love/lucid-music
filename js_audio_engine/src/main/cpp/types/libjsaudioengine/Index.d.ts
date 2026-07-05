export const createEngine: () => void;
export const executeScript: (scriptContent: string, scriptId: string) => boolean;
export const callFunction: (functionName: string, paramsJson: string) => string;
export const releaseEngine: () => void;
