package com.cxy.workbench;
import android.app.AlertDialog;
import android.content.*;
import android.net.Uri;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

final class NewsStore {
 static final String[] CATEGORIES={"AI 与 Agent","科研与医学","独立事业","自由生活"};
 static final AtomicBoolean busy=new AtomicBoolean();static long fetched;static String topic="全部";static JSONObject selected;static int listScroll;
 static String tags(JSONArray a){StringBuilder b=new StringBuilder();if(a!=null)for(int i=0;i<a.length();i++){if(i>0)b.append(" · ");b.append(a.optString(i));}return b.toString();}
 static ArrayList<JSONObject> items(JSONObject report){ArrayList<JSONObject> list=new ArrayList<>();if(report!=null)for(String key:new String[]{"highlights","otherItems"}){JSONArray entries=report.optJSONArray(key);if(entries!=null)for(int n=0;n<entries.length();n++){JSONObject item=entries.optJSONObject(n);if(item!=null)list.add(item);}}return list;}
 static String header(Context c){JSONObject r=Store.read(c,"news");if(r==null)return "";String date=r.optString("editionDate","");try{date=Integer.parseInt(date.substring(5,7))+"月"+Integer.parseInt(date.substring(8,10))+"日";}catch(RuntimeException e){}return date+" · "+items(r).size()+" 则";}
 static String version(Context c){return String.valueOf(Store.read(c,"news"))+Store.prefs(c).getString("newsError","")+topic+(selected==null?"":selected.optString("headline"));}
 static void refresh(Context c,Runnable after){if(!Store.configured(c)||!busy.compareAndSet(false,true))return;Store.IO.execute(()->{try{Store.cache(c,"news",Store.get(c,"/v1/information"));fetched=System.currentTimeMillis();Store.prefs(c).edit().putString("newsError","").apply();}catch(Exception e){Store.prefs(c).edit().putString("newsError","每日信息读取失败 · "+e.getMessage()).apply();}finally{busy.set(false);after.run();}});}
 static boolean matches(JSONObject item,String value){return value.equals("全部")||value.equals(item.optString("category"));}
 static LinkedHashMap<String,Integer> counts(ArrayList<JSONObject> all){LinkedHashMap<String,Integer> counts=new LinkedHashMap<>();for(String name:CATEGORIES)counts.put(name,0);for(JSONObject item:all){String category=item.optString("category");if(counts.containsKey(category))counts.put(category,counts.get(category)+1);}return counts;}

 static void coverage(MainActivity a){JSONObject report=Store.read(a,"news");if(report!=null)HyperStyle.dialog(new AlertDialog.Builder(HyperStyle.dialogContext(a)).setTitle(report.optString("title","本期信息")).setMessage(report.optString("coverageNote","")).setPositiveButton("知道了",null).create());}
 static void back(MainActivity a){selected=null;a.lastRender="";a.render();a.scroll.post(()->a.scroll.scrollTo(0,listScroll));HyperStyle.enter(a.content);}
 static void render(MainActivity a,LinearLayout parent){
  JSONObject report=Store.read(a,"news");String error=Store.prefs(a).getString("newsError","");if(!error.isEmpty())parent.addView(a.text(error,14,0xffa45e37));
  if(selected!=null){reader(a,parent,selected);return;}
  if(report==null){a.empty(parent,"news","还没有每日信息","",()->refresh(a,()->a.runOnUiThread(a::render)));return;}
  ArrayList<JSONObject> all=items(report);if(all.isEmpty()){a.empty(parent,"news","今天暂无已发布信息","",null);return;}
  LinkedHashMap<String,Integer> counts=counts(all);a.chip(a.filters,"\u5168\u90e8  "+all.size(),topic.equals("\u5168\u90e8"),()->selectTopic(a,"\u5168\u90e8"));for(Map.Entry<String,Integer> entry:counts.entrySet()){String tag=entry.getKey();a.chip(a.filters,tag+"  "+entry.getValue(),topic.equals(tag),()->selectTopic(a,tag));}

  if(!topic.equals("全部")&&counts.containsKey(topic)&&counts.get(topic)==0)a.empty(parent,"news","本期暂无该类信息","",null);
  for(JSONObject item:all){if(!matches(item,topic))continue;LinearLayout card=DeviceCards.panel(a,parent);card.setPadding(a.dp(18),a.dp(16),a.dp(18),a.dp(16));card.setBackground(HyperStyle.press(a,HyperStyle.surface(a),20));HyperStyle.pressMotion(card);
   String category=item.optString("category","待分类");boolean research=category.equals("科研与医学");String icon=research?"book":category.equals("独立事业")?"business":category.equals("自由生活")?"globe":"news";int tint=research?0xff23a684:category.equals("独立事业")?0xff8966db:category.equals("自由生活")?0xffb37a28:HyperStyle.accent(a);
   LinearLayout heading=new LinearLayout(a);heading.setGravity(Gravity.CENTER_VERTICAL);card.addView(heading);a.badge(heading,icon,tint,32);TextView tag=a.text(category,14,tint);tag.setPadding(a.dp(10),0,0,0);heading.addView(tag,new LinearLayout.LayoutParams(0,-2,1));ImageView arrow=new ImageView(a);arrow.setImageDrawable(HyperStyle.icon(a,"chevron",HyperStyle.muted(a)));heading.addView(arrow,new LinearLayout.LayoutParams(a.dp(14),a.dp(18)));
   TextView headline=a.text(item.optString("headline"),18,HyperStyle.ink(a));headline.setTypeface(android.graphics.Typeface.create("sans-serif-medium",0));headline.setPadding(0,a.dp(12),0,a.dp(6));card.addView(headline);
   TextView preview=a.text(item.optString("summary").split("\n\n",2)[0],15,HyperStyle.muted(a));preview.setMaxLines(2);preview.setEllipsize(android.text.TextUtils.TruncateAt.END);preview.setLineSpacing(a.dp(3),1);card.addView(preview);card.setContentDescription(item.optString("headline")+"，打开全文");card.setOnClickListener(v->{listScroll=a.scroll.getScrollY();selected=item;a.lastRender="";a.scroll.scrollTo(0,0);a.render();HyperStyle.enter(a.content);});
  }
 }
 static void selectTopic(MainActivity a,String value){topic=value;a.lastRender="";a.scroll.scrollTo(0,0);a.render();}
 static void reader(MainActivity a,LinearLayout parent,JSONObject item){
  LinearLayout card=DeviceCards.panel(a,parent);card.setPadding(a.dp(22),a.dp(20),a.dp(22),a.dp(22));JSONArray tags=item.optJSONArray("tags");String metadata=item.optString("category","");String fine=tags(tags);if(!fine.isEmpty())metadata+=(metadata.isEmpty()?"":" · ")+fine;String published=item.optString("publishedAt","");if(!published.isEmpty())metadata+=(metadata.isEmpty()?"":"  ·  ")+published;if(!metadata.isEmpty())card.addView(a.text(metadata,13,HyperStyle.muted(a)));
  TextView title=a.text(item.optString("headline"),22,HyperStyle.ink(a));title.setTypeface(android.graphics.Typeface.create("sans-serif-medium",0));title.setPadding(0,a.dp(14),0,a.dp(16));card.addView(title);TextView summary=a.text(item.optString("summary"),17,HyperStyle.ink(a));summary.setLineSpacing(a.dp(6),1);summary.setTextIsSelectable(true);card.addView(summary);String why=item.optString("why","");if(!why.isEmpty()){TextView text=a.text(why,16,HyperStyle.muted(a));text.setPadding(0,a.dp(16),0,0);card.addView(text);}
  for(String kind:new String[]{"sources","verificationLinks"}){JSONArray links=item.optJSONArray(kind);if(links==null||links.length()==0)continue;a.section(parent,kind.equals("sources")?"原始来源":"核查来源",String.valueOf(links.length()),"link",HyperStyle.accent(a));LinearLayout sources=DeviceCards.panel(a,parent);for(int n=0;n<links.length();n++){final String url=links.optString(n);Uri u=Uri.parse(url);if(!"https".equals(u.getScheme())&&!"http".equals(u.getScheme()))continue;String name=u.getHost()+(links.length()>1?"  ·  "+(n+1):"");a.setting(sources,"↗  "+name,()->{try{a.startActivity(new Intent(Intent.ACTION_VIEW,u));}catch(ActivityNotFoundException e){Toast.makeText(a,"没有可打开链接的浏览器",Toast.LENGTH_SHORT).show();}});}}
 }
}
