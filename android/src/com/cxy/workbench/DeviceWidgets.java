package com.cxy.workbench;

import android.app.*;
import android.appwidget.*;
import android.content.*;
import android.os.*;
import android.util.TypedValue;
import android.view.View;
import android.widget.RemoteViews;
import org.json.*;
import java.time.Instant;
import java.util.*;

final class DeviceWidgets {
 static final Class<?>[] PROVIDERS={DeviceWidget.class,MacWidget.class,WinPCWidget.class,LinuxWidget.class,GatewayWidget.class,PhoneWidget.class};
 static final String[] KINDS={"overview","mac","winpc","linux","gateway","phone"};
 static final String[] TITLES={"设备总览","Mac","WinPC","Linux","家庭网关","手机"};
 static void updateAll(Context c){
  // One cache read for this update, shared by all device widget instances.
  JSONObject snapshot=Store.read(c,"telemetry");
  AppWidgetManager manager=AppWidgetManager.getInstance(c);
  for(int index=0;index<PROVIDERS.length;index++){
   int[] ids=manager.getAppWidgetIds(new ComponentName(c,PROVIDERS[index]));
   for(int id:ids)render(c,manager,id,index,snapshot);
  }
 }
 static void receive(AppWidgetProvider provider,Context c,Intent intent){
  updateAll(c);
  boolean manual="com.cxy.workbench.REFRESH".equals(intent.getAction());
  boolean periodic=AppWidgetManager.ACTION_APPWIDGET_UPDATE.equals(intent.getAction());
  long now=System.currentTimeMillis(),last=Store.prefs(c).getLong("device-widget-refresh-request",0);
  // Multiple provider broadcasts share one background refresh window. Resize
  // and adding another instance only re-render the shared cache.
  if(manual||(periodic&&!LiveService.running&&now-last>=60000)){
   Store.prefs(c).edit().putLong("device-widget-refresh-request",now).apply();
   android.content.BroadcastReceiver.PendingResult result=provider.goAsync();
   Store.refresh(c,false,result::finish);
  }
 }
 static JSONObject device(JSONObject snapshot,String kind){return DeviceText.sample(snapshot,kind);}
 static boolean issue(JSONObject d){return d==null||(!d.isNull("issue")&&!d.optString("issue","").isEmpty())||(!d.isNull("error")&&!d.optString("error","").isEmpty());}
 static boolean fresh(JSONObject d,long now){return DeviceText.hardwareFresh(d,now);}
 static double value(JSONObject d,String field){return d==null||d.isNull(field)?Double.NaN:d.optDouble(field,Double.NaN);}
 static String memory(JSONObject d){double total=value(d,"memoryTotal"),used=value(d,"memoryUsed");return total>0?CardMetrics.percent(100*used/total):"—";}
 static long probeTime(JSONObject node){
  try{return Instant.parse(node.optString("probeAt","")).toEpochMilli();}catch(Exception e){return 0;}
 }
 static String nodeName(JSONObject n){return n==null?"未知":n.optString("name","未知");}
 static String health(String state){switch(state){case "healthy":return "可用";case "unhealthy":return "不可用";case "stale":return "探测过期";default:return "待探测";}}
 static String serviceLabel(String name){return name;}
 static String services(JSONObject linux){
  JSONArray services=linux==null?null:linux.optJSONArray("services");if(services==null||services.length()==0)return "服务状态待更新";
  StringBuilder b=new StringBuilder();
  for(int i=0;i<services.length();i++){JSONObject s=services.optJSONObject(i);if(s==null)continue;
   String name=s.optString("name"),state=s.optString("state","unknown");
   if(!name.startsWith("openwrt-"))continue;
   if(b.length()>0)b.append("  ");b.append(serviceLabel(name)).append("active".equals(state)?" ✓":"inactive".equals(state)?" ×":" ?");
  }return b.length()==0?"服务状态待更新":b.toString();
 }
 static void render(Context c,AppWidgetManager manager,int id,int kind,JSONObject snapshot){manager.updateAppWidget(id,BitmapCards.deviceViews(c,manager,id,kind,snapshot));}
}
