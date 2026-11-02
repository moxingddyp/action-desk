package com.cxy.workbench;
import org.json.*;
import java.util.*;
final class DeviceText {
 static JSONObject sample(JSONObject snapshot,String id){if(snapshot==null)return null;if(id.equals("phone"))return snapshot.optJSONObject("phone");JSONArray all=snapshot.optJSONArray("devices");if(all!=null)for(int i=0;i<all.length();i++){JSONObject x=all.optJSONObject(i);if(x!=null&&id.equals(x.optString("id")))return x;}return null;}
 static double number(JSONObject o,String key){return o==null||o.isNull(key)?Double.NaN:o.optDouble(key,Double.NaN);}
 static boolean hardwareFresh(JSONObject o,long now){if(o==null)return false;if("phone".equals(o.optString("id")))return o.optBoolean("hardwareSampleAvailable",false)&&o.optBoolean("hardwareFresh",false)&&CardMetrics.fresh(Store.sampleMillis(o,"receivedAt"),now,false);return CardMetrics.fresh(Store.sampleMillis(o,"receivedAt"),now,!o.isNull("issue")&&!o.optString("issue","").isEmpty()||!o.isNull("error")&&!o.optString("error","").isEmpty());}
 static String title(String id){return "phone".equals(id)?"手机":Presentation.title(id);}
 static String percent(JSONObject o,String key){return CardMetrics.percent(number(o,key));}
 static String memory(JSONObject o){double total=number(o,"memoryTotal"),used=number(o,"memoryUsed");return total>0?CardMetrics.percent(used*100/total):"—";}
 static String battery(JSONObject o){double p=number(o,"batteryPercent");if(Double.isNaN(p))return "电量未提供";return "电量 "+CardMetrics.percent(p)+(o.optBoolean("batteryCharging",false)?" · 充电":o.optBoolean("onACPower",false)?" · 接电":!o.isNull("onACPower")?" · 电池":" · 供电状态未提供");}
 static String network(JSONObject o){String v=o==null?"unknown":o.optString("networkType","unknown");switch(v){case "wifi":return "Wi-Fi";case "mobile":return "移动网络";case "ethernet":return "有线网络";case "vpn":return "系统VPN";case "none":return "无活动网络";default:return "网络类型未提供";}}
 static String link(JSONObject sample,long now){JSONObject p=sample==null?null:sample.optJSONObject("privateLink");long observed=Store.sampleMillis(p,"observedAt");if(p==null||!CardMetrics.fresh(observed,now,false))return "家庭网关 · 状态待更新";String kind=p.optString("kind","unknown");if(!p.isNull("online")&&!p.optBoolean("online"))return "家庭网关 · 离线";String path;switch(kind){case "lan-direct":path="局域网直连";break;case "direct":path="直连";break;case "derp":case "peer-relay":path="中继";break;case "idle":return "家庭网关 · 在线 · 路径空闲";case "offline":return "家庭网关 · 离线";default:return p.optBoolean("online",false)?"家庭网关 · 在线 · 路径未知":"家庭网关 · 状态待更新";}
  String version=p.optString("transportVersion","");if(!version.equals("IPv4")&&!version.equals("IPv6"))version="协议未提供";return "家庭网关 · 在线 · "+path+" · "+version;
 }
 static String rates(JSONObject o,boolean fresh){return "↓ "+(fresh?CardMetrics.bytes(number(o,"download"),true):"—")+"/s     ↑ "+(fresh?CardMetrics.bytes(number(o,"upload"),true):"—")+"/s";}
 static String diskLine(JSONObject d){double total=number(d,"total"),used=number(d,"used");return d.optString("name","磁盘")+"  "+(total>0?CardMetrics.percent(used*100/total):"—")+"  "+CardMetrics.bytes(used,false)+" / "+CardMetrics.bytes(total,false);}
 static String stamp(JSONObject d){return Store.stamp(Store.sampleMillis(d,"receivedAt"));}
}
