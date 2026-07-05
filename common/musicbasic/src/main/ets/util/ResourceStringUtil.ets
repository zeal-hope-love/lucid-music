/*
 * getResourceString - 从 UIContext 获取 Resource 字符串值
 */
import { UIContext } from '@kit.ArkUI'

export function getResourceString(context: UIContext, resource: Resource, instance?: Object): string {
  try {
    return context.getHostContext()!.resourceManager.getStringSync(resource.id)
  } catch (e) {
    return 'Lucid Music'
  }
}
