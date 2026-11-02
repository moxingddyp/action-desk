package com.cxy.workbench;
import android.content.*;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.util.*;

final class DeviceCards {
 static int dp(Context c,int value){return (int)(value*c.getResources().getDisplayMetrics().density+.5f);}
 static TextView text(Context c,String value,int size,int color){TextView t=new TextView(c);t.setText(value);t.setTextSize(size);t.setTextColor(HyperStyle.color(c,color));t.setPadding(0,dp(c,3),0,dp(c,3));return t;}
 static LinearLayout panel(Context c,LinearLayout parent){LinearLayout card=new LinearLayout(c);card.setOrientation(1);card.setPadding(dp(c,20),dp(c,16),dp(c,20),dp(c,16));GradientDrawable bg=new GradientDrawable();bg.setColor(HyperStyle.surface(c));bg.setCornerRadius(dp(c,16));card.setBackground(bg);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.setMargins(0,dp(c,8),0,dp(c,6));parent.addView(card,lp);return card;}
 static void render(Context c,LinearLayout holder,JSONObject snapshot,String selected){holder.removeAllViews();if("overview".equals(selected)){for(String id:new String[]{"mac","winpc","linux","phone"})overview(c,holder,snapshot,id);gateway(c,holder,snapshot);}else if("gateway".equals(selected))gateway(c,holder,snapshot);else hardware(c,holder,snapshot,selected);}
 static void overview(Context c,LinearLayout holder,JSONObject snapshot,String id){
  JSONObject d=DeviceText.sample(snapshot,id);long now=System.currentTimeMillis();boolean fresh=DeviceText.hardwareFresh(d,now),phone=id.equals("phone");
  LinearLayout card=panel(c,holder);LinearLayout header=new LinearLayout(c);header.setGravity(Gravity.CENTER_VERTICAL);card.addView(header);TextView title=text(c,DeviceText.title(id),21,0xff19212e);title.setTypeface(null,Typeface.BOLD);header.addView(title,new LinearLayout.LayoutParams(0,-2,1));header.addView(text(c,fresh?"已更新  ›":"未更新  ›",12,fresh?0xff25a56a:0xff8893a0));statusChips(c,card,d,now);
  LinearLayout row=new LinearLayout(c);card.addView(row);if(phone)metric(c,row,"电量",DeviceText.percent(d,"batteryPercent"));else metric(c,row,"CPU",DeviceText.percent(d,"cpu"));metric(c,row,"内存",DeviceText.memory(d));if(phone){JSONArray disks=d==null?null:d.optJSONArray("disks");JSONObject disk=disks==null?null:disks.optJSONObject(0);double total=DeviceText.number(disk,"total"),used=DeviceText.number(disk,"used");metric(c,row,"存储",total>0?CardMetrics.percent(used*100/total):"—");}else metric(c,row,"GPU",DeviceText.percent(d,"gpu"));
  if(!phone)card.addView(text(c,DeviceText.rates(d,fresh),14,0xff087bfa));
  card.setOnClickListener(v->{MainActivity a=(MainActivity)c;a.device=id;a.lastRender="";a.scroll.scrollTo(0,0);a.render();});
 }
 static void hardware(Context c,LinearLayout holder,JSONObject snapshot,String id){
  JSONObject d=DeviceText.sample(snapshot,id);long now=System.currentTimeMillis();boolean phone=id.equals("phone"),fresh=DeviceText.hardwareFresh(d,now);
  LinearLayout card=panel(c,holder);LinearLayout header=new LinearLayout(c);header.setGravity(Gravity.CENTER_VERTICAL);card.addView(header);
  TextView title=text(c,DeviceText.title(id),20,0xff18334f);title.setTypeface(null,Typeface.BOLD);header.addView(title,new LinearLayout.LayoutParams(0,-2,1));header.addView(text(c,fresh?"● 已更新":"● 未更新",11,fresh?0xff247c57:0xff916f3e));
  statusChips(c,card,d,now);
  if(id.equals("mac")||phone){card.addView(text(c,DeviceText.battery(d)+(fresh?"":" · 上次数据"),12,0xff60748a));}
  LinearLayout metrics=new LinearLayout(c);card.addView(metrics);if(phone){metric(c,metrics,"电量",DeviceText.percent(d,"batteryPercent"));metric(c,metrics,"内存",DeviceText.memory(d));}else{metric(c,metrics,"CPU",DeviceText.percent(d,"cpu"));metric(c,metrics,"GPU",DeviceText.percent(d,"gpu"));metric(c,metrics,"内存",DeviceText.memory(d));}
  card.addView(text(c,phone?DeviceText.network(d):DeviceText.rates(d,fresh),15,0xff1680ff));
  double used=DeviceText.number(d,"memoryUsed"),total=DeviceText.number(d,"memoryTotal");card.addView(text(c,"内存  "+CardMetrics.bytes(used,false)+" / "+CardMetrics.bytes(total,false),11,0xff6b7f91));
  JSONArray disks=d==null?null:d.optJSONArray("disks");if(disks==null||disks.length()==0)card.addView(text(c,"存储数据待上报",12,0xff7b8c9d));else for(int i=0;i<disks.length();i++){
   JSONObject disk=disks.optJSONObject(i);if(disk==null)continue;card.addView(text(c,DeviceText.diskLine(disk),12,0xff536b82));ProgressBar bar=new ProgressBar(c,null,android.R.attr.progressBarStyleHorizontal);bar.setMax(100);double capacity=DeviceText.number(disk,"total"),inUse=DeviceText.number(disk,"used");bar.setProgress(capacity>0?(int)Math.max(0,Math.min(100,100*inUse/capacity)):0);bar.setProgressTintList(android.content.res.ColorStateList.valueOf(0xff1680ff));bar.setProgressBackgroundTintList(android.content.res.ColorStateList.valueOf(0xffdeebfb));card.addView(bar,new LinearLayout.LayoutParams(-1,dp(c,5)));
  }
  String stamp="采样 "+DeviceText.stamp(d);
  if(phone){String error=Store.prefs(c).getString("phoneError","");if(!error.isEmpty())stamp=error;else if(Store.prefs(c).getString("phoneToken","").isEmpty())stamp="手机上报未启用 · 导入新版连接文件后启用";else if(!fresh)stamp="手机硬件待上报或已过期 · "+DeviceText.stamp(d);}
  card.addView(text(c,stamp,10,0xff7a8c9f));
 }
 static void statusChips(Context c,LinearLayout card,JSONObject sample,long now){LinearLayout row=new LinearLayout(c);row.setPadding(0,dp(c,4),0,dp(c,4));card.addView(row);String priv=WidgetNetwork.privateLabel(sample,now);if(WidgetNetwork.lanDirect(sample,now))statusChip(c,row,"局域网直连",0xff0575ff,HyperStyle.wash(c));statusChip(c,row,priv,WidgetNetwork.privateConnected(priv)?0xff25a56a:0xff8893a0,WidgetNetwork.privateConnected(priv)?(HyperStyle.dark(c)?0xff20372b:0xffe1f2ec):HyperStyle.soft(c));}
 static void statusChip(Context c,LinearLayout row,String label,int dot,int bg){TextView t=text(c,"",11,0xff31475b);android.text.SpannableString text=new android.text.SpannableString("● "+label);text.setSpan(new android.text.style.ForegroundColorSpan(dot),0,1,android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);t.setText(text);t.setPadding(dp(c,8),dp(c,4),dp(c,8),dp(c,4));GradientDrawable shape=new GradientDrawable();shape.setColor(bg);shape.setCornerRadius(dp(c,20));t.setBackground(shape);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-2,-2);lp.setMargins(0,0,dp(c,6),0);row.addView(t,lp);}
 static void metric(Context c,LinearLayout row,String label,String value){LinearLayout col=new LinearLayout(c);col.setOrientation(1);col.setPadding(0,dp(c,8),0,dp(c,8));row.addView(col,new LinearLayout.LayoutParams(0,-2,1));col.addView(text(c,label,11,0xff6d7f92));TextView n=text(c,value,21,0xff183b64);n.setTypeface(null,Typeface.BOLD);col.addView(n);}
 static void gateway(Context c,LinearLayout holder,JSONObject snapshot){
  JSONObject linux=DeviceText.sample(snapshot,"linux"),proxy=linux==null?null:linux.optJSONObject("proxy");long now=System.currentTimeMillis();boolean fresh=DeviceText.hardwareFresh(linux,now)&&proxy!=null&&proxy.optDouble("sampledAtUnix",0)>0&&now-(long)(proxy.optDouble("sampledAtUnix")*1000)<18000;
  LinearLayout card=panel(c,holder);TextView title=text(c,"家庭网关",20,0xff18334f);title.setTypeface(null,Typeface.BOLD);card.addView(title);card.addView(text(c,fresh?"● 状态已更新":"● 状态未更新",11,fresh?0xff247c57:0xff916f3e));card.addView(text(c,(fresh?"当前出口  ":"上次出口  ")+(proxy==null?"未知":proxy.optString("selected","未知")),15,0xff1680ff));
  JSONObject gateway=snapshot==null?null:snapshot.optJSONObject("gateway");statusChips(c,card,gateway,now);
  JSONArray services=linux==null?null:linux.optJSONArray("services");if(services!=null)for(int i=0;i<services.length();i++){JSONObject service=services.optJSONObject(i);if(service!=null)card.addView(text(c,DeviceWidgets.serviceLabel(service.optString("name"))+"  "+(fresh?("active".equals(service.optString("state"))?"运行中":"inactive".equals(service.optString("state"))?"未运行":"未知"):"未更新"),12,0xff536b82));}
  JSONArray nodes=proxy==null?null:proxy.optJSONArray("nodes");if(nodes!=null)for(int i=0;i<nodes.length();i++){JSONObject node=nodes.optJSONObject(i);if(node==null)continue;boolean current=CardMetrics.probeRecent(fresh,DeviceWidgets.probeTime(node),now),healthy=CardMetrics.nodeFresh(fresh,node.optString("health"),DeviceWidgets.probeTime(node),now);String line=node.optString("name","未知节点")+"\n"+(current?DeviceWidgets.health(node.optString("health")):"探测过期")+(healthy&&!node.isNull("latencyMs")?String.format(Locale.CHINA," · %.0f ms",node.optDouble("latencyMs")):" · —");card.addView(text(c,line,13,0xff314f6d));card.addView(text(c,"代理HTTP探测 · "+Store.stamp(DeviceWidgets.probeTime(node)),10,0xff7a8c9f));}
 }
}
