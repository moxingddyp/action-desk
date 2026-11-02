package com.cxy.workbench;
import org.json.*;
import java.util.*;
import java.time.Instant;

/** Shared drawing geometry used by Android Canvas and the checked desktop preview adapter. */
final class CardPainter {
 interface Surface {
  void rect(float x,float y,float w,float h,float r,int color);
  void line(float x1,float y1,float x2,float y2,float width,int color);
  void circle(float x,float y,float r,int color);
  void glow(float x,float y,float r,int color);
  void arc(float x,float y,float r,float stroke,float start,float sweep,int color);
  void text(String s,float x,float baseline,float size,int color,boolean bold);
  float measure(String s,float size,boolean bold);
 }
 static final int BLUE=0xff3482ff,GREEN=0xff25bb65,ORANGE=0xffdd963e,TEAL=0xff33a69a,PURPLE=0xff858fdb;
 static final class Theme {
  final int bg,panel,ink,muted,faint,blueWash,greenWash,orangeWash;
  Theme(boolean dark){bg=dark?0xff242424:0xffffffff;panel=dark?0xff303030:0xfff7f7f7;ink=dark?0xfff2f2f2:0xff101010;muted=dark?0xffa4a4a4:0xff7b7b7b;faint=dark?0xff393939:0xffe8e8e8;blueWash=dark?0xff1b3559:0xffe0edff;greenWash=dark?0xff163f37:0xffe1f2ec;orangeWash=dark?0xff453627:0xfff7ebdc;}
 }
 static String trim(Surface p,String text,float width,float size,boolean bold){if(text==null)return "—";if(p.measure(text,size,bold)<=width)return text;while(text.length()>0&&p.measure(text+"…",size,bold)>width)text=text.substring(0,text.length()-1);return text+"…";}
 static String bytes(double n){return CardMetrics.bytes(n,false).replaceAll("([0-9.])([KMGT]?B)$","$1 $2");}
 static String rate(double n,boolean fresh){return !fresh||Double.isNaN(n)||Double.isInfinite(n)?"—":bytes(n)+"/s";}
 static String metric(JSONObject d,String key){double v=DeviceText.number(d,key);return CardMetrics.percent(v);}
 static void icon(Surface p,String kind,float x,float y,float size,int color){
  float u=size/20f;
  if(kind.equals("mac")){p.rect(x+3*u,y+3*u,14*u,11*u,u,color);p.rect(x+4*u,y+4*u,12*u,9*u,.4f*u,0xffe0edff);p.line(x,y+15*u,x+20*u,y+15*u,1.6f*u,color);}
  else if(kind.equals("phone")){p.rect(x+5*u,y+u,10*u,18*u,2*u,color);p.rect(x+6.2f*u,y+3*u,7.6f*u,13*u,u,0xffe7f0fc);p.circle(x+10*u,y+17*u,.6f*u,0xffe7f0fc);}
  else if(kind.equals("cpu")){p.rect(x+4*u,y+4*u,12*u,12*u,2*u,color);p.rect(x+7*u,y+7*u,6*u,6*u,u,0xfff5faff);for(int i=5;i<=15;i+=5){p.line(x+i*u,y+u,x+i*u,y+4*u,u,color);p.line(x+i*u,y+16*u,x+i*u,y+19*u,u,color);p.line(x+u,y+i*u,x+4*u,y+i*u,u,color);p.line(x+16*u,y+i*u,x+19*u,y+i*u,u,color);}}
  else if(kind.equals("gpu")){for(int i=0;i<3;i++){float yy=y+(5+i*4)*u;p.line(x+2*u,yy,x+10*u,yy+4*u,1.8f*u,color);p.line(x+10*u,yy+4*u,x+18*u,yy,1.8f*u,color);}}
  else if(kind.equals("memory")){p.rect(x+u,y+5*u,18*u,10*u,2*u,color);for(int i=4;i<=16;i+=4){p.rect(x+i*u,y+7*u,2*u,5*u,.5f*u,0xfff5faff);p.line(x+i*u,y+15*u,x+i*u,y+18*u,u,color);}}
  else if(kind.equals("disk")){p.rect(x+2*u,y+5*u,16*u,11*u,2*u,color);p.line(x+4*u,y+8*u,x+16*u,y+8*u,u,0xffeef5ff);p.circle(x+15*u,y+13*u,u,0xffeef5ff);}
  else if(kind.equals("list")){for(int i=0;i<3;i++){p.circle(x+2*u,y+(4+i*6)*u,u,color);p.line(x+6*u,y+(4+i*6)*u,x+18*u,y+(4+i*6)*u,1.5f*u,color);}}
  else if(kind.equals("ring")){p.arc(x+10*u,y+10*u,7*u,3*u,-90,270,color);p.arc(x+10*u,y+10*u,7*u,3*u,190,70,TEAL);}
  else if(kind.equals("winpc")){p.rect(x+2*u,y+2*u,16*u,11*u,u,color);p.line(x+10*u,y+13*u,x+10*u,y+18*u,1.5f*u,color);p.line(x+5*u,y+18*u,x+15*u,y+18*u,1.5f*u,color);}
  else {for(int i=0;i<3;i++){p.rect(x+2*u,y+(2+i*6)*u,16*u,4*u,u,color);p.circle(x+5*u,y+(4+i*6)*u,.7f*u,0xfff4f8fe);}}
 }
 static void chip(Surface p,String label,float x,float y,float w,boolean yes,Theme t){boolean lan=label.startsWith("局域网");p.rect(x,y,w,18,9,yes?(lan?t.blueWash:t.greenWash):t.orangeWash);p.circle(x+7,y+9,2,yes?(lan?BLUE:GREEN):ORANGE);p.text(trim(p,label,w-17,7.5f,true),x+13,y+12,7.5f,t.ink,true);}
 static boolean current(JSONObject o,String field,long now){return CardMetrics.fresh(Store.sampleMillis(o,field),now,false);}
 static String lanLabel(JSONObject sample,long now){JSONObject l=sample==null?null:sample.optJSONObject("lanLink");if(l==null||!current(l,"observedAt",now))return "局域网未知";return l.optString("state").equals("online")?"局域网在线":l.optString("state").equals("offline")?"局域网离线":"局域网未知";}
 static String privateLabel(JSONObject sample,long now){JSONObject l=sample==null?null:sample.optJSONObject("privateLink");if(l==null||!current(l,"observedAt",now)||l.isNull("online"))return "私网未知";return l.optBoolean("online")?"私网在线":"私网离线";}
 static void tile(Surface p,float x,float y,float w,String title,String value,String icon,int tint,Theme t){p.rect(x,y,w,41,9,t.panel);icon(p,icon,x+6,y+6,8,tint);p.text(title,x+18,y+13,8,t.muted,false);p.text(trim(p,value,w-12,15,true),x+6,y+32,15,t.ink,true);}
 static String displayDisk(String name){return name.equals("/")||name.equals("Macintosh HD")?"系统盘":name.equals("/mnt/moyue-archive")?"机械盘":name;}
 static void device(Surface p,JSONObject snapshot,String kind,long now,float h,boolean dark){
  Theme t=new Theme(dark);p.rect(0,0,360,h,22,t.bg);p.glow(345,12,125,dark?0x220575ff:0x1a0575ff);
  boolean gateway=kind.equals("gateway"),overview=kind.equals("overview");JSONObject d=gateway?snapshot==null?null:snapshot.optJSONObject("gateway"):DeviceText.sample(snapshot,kind);JSONObject linux=DeviceText.sample(snapshot,"linux");
  p.rect(12,12,23,23,8,t.blueWash);icon(p,kind,15,15,17,BLUE);String title=gateway?"家庭网关":overview?"设备总览":DeviceText.title(kind);p.text(title,41,28,13,t.ink,true);
  if((kind.equals("mac")||kind.equals("phone"))&&d!=null&&!d.isNull("batteryPercent")){float x=41+p.measure(title,13,true)+7;int tint=d.optDouble("batteryPercent")<20?ORANGE:t.muted;p.rect(x,19,10,5.5f,1,tint);p.rect(x+1,20,8,3.5f,.3f,t.bg);p.rect(x+1,20,8*(float)Math.max(0,Math.min(1,d.optDouble("batteryPercent")/100)),3.5f,.3f,tint);p.rect(x+10.5f,20.3f,1.2f,2.6f,.4f,tint);String pct=metric(d,"batteryPercent");p.text(pct,x+15,27,9,tint,true);float bx=x+18+p.measure(pct,9,true);if(d.optBoolean("onACPower",false)){p.line(bx,20,bx,24,1.1f,t.muted);p.line(bx+3,20,bx+3,24,1.1f,t.muted);p.rect(bx-1,23,5,3,1,t.muted);p.line(bx+1.5f,25,bx+1.5f,28,1,t.muted);}}
  if(!overview){String lan=lanLabel(d,now),priv=privateLabel(d,now);if(lan.equals("局域网在线"))chip(p,lan,224,14,62,true,t);chip(p,priv,292,14,56,priv.equals("私网在线"),t);}
  if(gateway){gatewayBody(p,linux,now,h,t);return;}
  if(overview){overviewBody(p,snapshot,now,h,t);return;}
  boolean fresh=DeviceText.hardwareFresh(d,now);float mw=(231-8)/3;
  tile(p,12,43,mw,"CPU",metric(d,"cpu"),"cpu",BLUE,t);tile(p,16+mw,43,mw,"GPU",metric(d,"gpu"),"gpu",TEAL,t);tile(p,20+2*mw,43,mw,"内存",DeviceText.memory(d),"memory",PURPLE,t);
  p.rect(250,43,98,43,10,t.panel);p.text("↓",263,59,11,BLUE,true);p.text(trim(p,rate(DeviceText.number(d,"download"),fresh),72,11,true),278,59,11,t.ink,true);p.text("↑",263,78,11,BLUE,true);p.text(trim(p,rate(DeviceText.number(d,"upload"),fresh),72,11,true),278,78,11,t.ink,true);
  p.text(bytes(DeviceText.number(d,"memoryUsed"))+" / "+bytes(DeviceText.number(d,"memoryTotal")),12,94,6.8f,t.muted,false);
  JSONArray disks=d==null?null:d.optJSONArray("disks");int n=disks==null?0:disks.length(),rows=(n+1)/2;float diskTop=105,available=Math.max(18,h-140);float gap=Math.min(24,available/Math.max(1,rows));float yStart=diskTop+Math.max(0,(available-rows*gap)/2);
  if(n==0)p.text(fresh?"磁盘数据未提供":"硬件数据待更新",12,yStart+10,8,t.muted,false);
  for(int i=0;i<n;i++){JSONObject disk=disks.optJSONObject(i);if(disk==null)continue;float x=i%2==0?12:186,y=yStart+(i/2)*gap,w=162;float fs=gap<17?6.5f:7.5f;icon(p,"disk",x,y,8,BLUE);String name=displayDisk(disk.optString("name","磁盘"));String capacity=bytes(DeviceText.number(disk,"used"))+" / "+bytes(DeviceText.number(disk,"total"));capacity=trim(p,capacity,100,fs,false);float cw=p.measure(capacity,fs,false);p.text(trim(p,name,w-cw-12,8,true),x+13,y+7,8,t.ink,true);p.text(capacity,x+w-cw,y+7,fs,t.muted,false);p.rect(x,y+12,w,3,1.5f,t.faint);double total=DeviceText.number(disk,"total"),used=DeviceText.number(disk,"used");if(total>0&&!Double.isNaN(used))p.rect(x,y+12,w*(float)Math.max(0,Math.min(1,used/total)),3,1.5f,0xff4595ff);}
  String footer="采样 "+time(Store.sampleMillis(d,"receivedAt"));if(kind.equals("mac")||kind.equals("phone")){String path=DeviceText.link(d,now).replace("家庭网关 · ","").replace("在线 · ","");footer+=" · 到家庭网关 · "+path;}
  if(!fresh)footer="未更新 · "+footer;p.text(trim(p,footer,305,7.2f,false),12,h-11,7.2f,t.muted,false);p.text("↻",319,h-10,12,t.muted,false);p.text("↗",341,h-10,12,t.muted,false);
 }
 static String time(long ms){return ms<=0?"—":new java.text.SimpleDateFormat("HH:mm:ss",Locale.CHINA).format(new Date(ms));}
 static void overviewBody(Surface p,JSONObject snapshot,long now,float h,Theme t){String[] ids={"mac","winpc","linux","phone"};float rowH=(h-70)/2;for(int i=0;i<4;i++){float x=i%2==0?12:186,y=44+(i/2)*rowH;JSONObject d=DeviceText.sample(snapshot,ids[i]);p.rect(x,y,162,rowH-7,10,t.panel);icon(p,ids[i],x+9,y+9,12,BLUE);p.text(DeviceText.title(ids[i]),x+28,y+19,10,t.ink,true);p.text("CPU "+metric(d,"cpu")+"   内存 "+DeviceText.memory(d),x+9,y+38,9,t.ink,true);p.text(lanLabel(d,now)+" · "+privateLabel(d,now),x+9,y+rowH-16,7,t.muted,false);}p.text("逐台采样时间与状态以详情为准",12,h-10,7,t.muted,false);p.text("↗",341,h-10,12,t.muted,false);}
 static void gatewayBody(Surface p,JSONObject linux,long now,float h,Theme t){JSONObject proxy=linux==null?null:linux.optJSONObject("proxy");boolean fresh=DeviceText.hardwareFresh(linux,now)&&proxy!=null&&now-(long)(proxy.optDouble("sampledAtUnix",0)*1000)<18000;
  JSONArray services=linux==null?null:linux.optJSONArray("services");String[] keys={"openwrt-mihomo","openwrt-dnsmasq","openwrt-tailscale"},labels={"代理","DNS","私网"};for(int k=0;k<3;k++){boolean ok=false;if(services!=null)for(int z=0;z<services.length();z++){JSONObject s=services.optJSONObject(z);if(s!=null&&keys[k].equals(s.optString("name"))&&"active".equals(s.optString("state")))ok=true;}p.circle(16+k*49,46,2,fresh&&ok?GREEN:ORANGE);p.text(labels[k],22+k*49,49,8,t.muted,false);}
  p.text(fresh?"当前出口":"上次出口",12,65,8,t.muted,false);p.text(trim(p,proxy==null?"等待出口信息":proxy.optString("selected","未知"),275,11,true),62,65,11,t.ink,true);
  JSONArray a=proxy==null?null:proxy.optJSONArray("nodes");List<JSONObject> nodes=new ArrayList<>();if(a!=null)for(int z=0;z<a.length();z++)if(a.optJSONObject(z)!=null)nodes.add(a.optJSONObject(z));nodes.sort((left,right)->Boolean.compare(right.optBoolean("selected"),left.optBoolean("selected")));int count=nodes.size();if(count==0)p.text("节点状态待更新",12,100,9,t.muted,false);
  for(int i=0;i<Math.min(2,count);i++){JSONObject n=nodes.get(i);if(n==null)continue;float x=12+i*174;p.rect(x,75,162,Math.max(54,h-104),12,t.panel);icon(p,"gateway",x+9,84,10,BLUE);p.text(trim(p,(n.optBoolean("selected")?"当前 ":"备用 ")+n.optString("name","未知节点"),129,8.5f,true),x+24,92,8.5f,t.ink,true);boolean healthy=CardMetrics.nodeFresh(fresh,n.optString("health"),DeviceWidgets.probeTime(n),now);p.text(healthy&&!n.isNull("latencyMs")?String.format(Locale.CHINA,"%.0f",n.optDouble("latencyMs")):"—",x+9,119,20,BLUE,true);p.text("ms",x+58,118,8,t.muted,false);p.circle(x+147,113,2,healthy?GREEN:ORANGE);p.text("探测 "+time(DeviceWidgets.probeTime(n)),x+9,h-39,7,t.muted,false);}
  p.text((count>2?"另有 "+(count-2)+" 个节点 · ":"")+"代理HTTP探测 · 采样 "+time(Store.sampleMillis(linux,"receivedAt")),12,h-10,7,t.muted,false);p.text("↻",319,h-10,12,t.muted,false);p.text("↗",341,h-10,12,t.muted,false);
 }
}
