package com.cxy.workbench;
import org.json.JSONObject;
/** Widget labels describe only a fresh observed path, independent of hardware freshness. */
final class WidgetNetwork {
 static final String UNKNOWN="私网状态未知",DISCONNECTED="私网未连接",ONLINE="私网在线";
 static boolean fresh(JSONObject o,long now){return o!=null&&CardMetrics.fresh(Store.sampleMillis(o,"observedAt"),now,problem(o));}
 static boolean problem(JSONObject o){return o!=null&&((!o.isNull("issue")&&!o.optString("issue","").isEmpty())||(!o.isNull("error")&&!o.optString("error","").isEmpty()));}
 static boolean lanDirect(JSONObject d,long now){JSONObject l=d==null?null:d.optJSONObject("lanLink");return fresh(l,now)&&"online".equals(l.optString("state"));}
 static String privateLabel(JSONObject d,long now){JSONObject p=d==null?null:d.optJSONObject("privateLink");if(!fresh(p,now))return UNKNOWN;if("gateway".equals(d.optString("id")))return p.isNull("online")?UNKNOWN:p.optBoolean("online")?ONLINE:DISCONNECTED;String kind=p.optString("kind","unknown");if((!p.isNull("online")&&!p.optBoolean("online"))||"offline".equals(kind))return DISCONNECTED;if(!p.optBoolean("online",false))return UNKNOWN;if("direct".equals(kind)||"lan-direct".equals(kind)){String protocol=p.optString("transportVersion","");return "私网直连"+(protocol.equals("IPv4")||protocol.equals("IPv6")?" · "+protocol:"");}if("derp".equals(kind)||"peer-relay".equals(kind))return "私网中继";return UNKNOWN;}
 static boolean privateConnected(String label){return label.startsWith("私网直连")||label.equals("私网中继")||label.equals(ONLINE);}
}
