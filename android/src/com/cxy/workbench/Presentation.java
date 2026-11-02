package com.cxy.workbench;
import org.json.*;
import java.util.*;
final class Presentation {
 static String metric(JSONObject o,String key){return !o.has(key)||o.isNull(key)?"—":String.format(Locale.CHINA,"%.0f%%",o.optDouble(key));}
 static String rate(JSONObject o,String key){if(!o.has(key)||o.isNull(key))return "—";double n=o.optDouble(key);String[] u={"B/s","KB/s","MB/s","GB/s"};int i=0;while(n>=1024&&i<3){n/=1024;i++;}return String.format(Locale.CHINA,"%.1f %s",n,u[i]);}
 static String title(String id){switch(id){case "mac":return "Mac";case "winpc":return "WinPC";case "linux":return "Linux";default:return id;}}
 static String devices(JSONObject data,boolean detail){
  if(data==null)return "等待设备采样";
  JSONArray a=data.optJSONArray("devices");if(a==null)return "等待设备采样";
  StringBuilder out=new StringBuilder();
  for(int i=0;i<a.length();i++){
   JSONObject d=a.optJSONObject(i);if(d==null)continue;
   long at=Store.sampleMillis(d,"receivedAt");long age=at==0?Long.MAX_VALUE:Math.max(0,(System.currentTimeMillis()-at)/1000);
   boolean fresh=age<12&&(d.isNull("issue")||d.optString("issue","").isEmpty())&&(d.isNull("error")||d.optString("error","").isEmpty());
   out.append(title(d.optString("id"))).append(fresh?" · 已采样":" · 未更新").append('\n');
   out.append("CPU ").append(metric(d,"cpu")).append("  GPU ").append(metric(d,"gpu"));
   if(d.optDouble("memoryTotal",0)>0)out.append("  内存 ").append(String.format(Locale.CHINA,"%.0f%%",100*d.optDouble("memoryUsed")/d.optDouble("memoryTotal")));
   out.append("\n↓ ").append(fresh?rate(d,"download"):"—").append("  ↑ ").append(fresh?rate(d,"upload"):"—").append('\n');
   if(detail){out.append("采样 ").append(Store.stamp(at)).append('\n');
    JSONArray disks=d.optJSONArray("disks");if(disks!=null)for(int j=0;j<disks.length();j++){JSONObject disk=disks.optJSONObject(j);if(disk!=null&&disk.optDouble("total",0)>0)out.append(disk.optString("name")).append(" ").append(String.format(Locale.CHINA,"%.0f%%",100*disk.optDouble("used")/disk.optDouble("total"))).append('\n');}
    JSONArray services=d.optJSONArray("services");if(services!=null)for(int j=0;j<services.length();j++){JSONObject x=services.optJSONObject(j);if(x!=null)out.append(x.optString("name")).append(" · ").append(x.optString("state")).append('\n');}
   }
   JSONObject p=d.optJSONObject("proxy");if(p!=null){out.append(fresh?"当前出口 ":"上次出口 ").append(p.optString("selected","未知")).append('\n');JSONArray ns=p.optJSONArray("nodes");if(ns!=null)for(int j=0;j<ns.length();j++){JSONObject n=ns.optJSONObject(j);if(n==null)continue;out.append(n.optString("name")).append(" · ").append(n.optString("health","unknown"));if(fresh&&"healthy".equals(n.optString("health"))&&n.has("latencyMs")&&!n.isNull("latencyMs"))out.append(String.format(Locale.CHINA," · %.0f ms",n.optDouble("latencyMs")));out.append('\n');}}
   out.append('\n');
  }return out.toString().trim();
 }
 static boolean inGroup(JSONObject item,String group){JSONArray a=item.optJSONArray("tags");if(a!=null){for(int j=0;j<a.length();j++)if(group.equals(a.optString(j)))return true;return false;}return group.equals(item.optString("group"));}
 static String actions(JSONObject data,boolean detail,String group){
  if(data==null)return "等待Mac同步事项";
  JSONArray a=data.optJSONArray("items");if(a==null)return "暂无事项";
  StringBuilder b=new StringBuilder();int shown=0;
  for(int i=0;i<a.length();i++){
   JSONObject item=a.optJSONObject(i);if(item==null||(!group.isEmpty()&&!inGroup(item,group)))continue;
   if(!detail&&shown>=4)break;
   b.append(item.optString("label",item.optString("title"))).append('\n');
   b.append("下一步：").append(item.optString("next","—")).append('\n');
   if(detail){b.append("进度：").append(item.optString("current","—")).append('\n');String deadline=item.optString("deadline","");if(!deadline.isEmpty())b.append("期限：").append(deadline).append('\n');}
   b.append('\n');shown++;
  }
  if(shown==0)b.append("本分类暂无事项\n");
  if(detail){JSONArray e=data.optJSONArray("calendarEvents");if(e!=null&&e.length()>0){b.append("日程\n");for(int i=0;i<e.length();i++){JSONObject x=e.optJSONObject(i);if(x!=null)b.append(x.optString("date")).append(' ').append(x.optString("time")).append(' ').append(x.optString("title")).append('\n');}}}
  return b.toString().trim();
 }
 static String actionSource(JSONObject data){if(data==null)return "尚未同步";return "来源生成："+data.optString("generatedAt","未知")+"；Mac离线时保留最后同步版本";}
}
