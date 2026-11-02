package com.cxy.workbench;

import android.graphics.Typeface;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.util.*;

/** Compact reading order; all progress remains a read-only view of the original snapshot. */
final class ActionPage {
 static final String[] GROUPS={"全部","优先做","正在做","当前可做","条件做"};
 static int count(JSONArray items,String group){int count=0;if(items!=null)for(int n=0;n<items.length();n++){JSONObject item=items.optJSONObject(n);if(item!=null&&(group.equals("全部")||Presentation.inGroup(item,group)))count++;}return count;}
 static int tint(MainActivity a,String group){return group.equals("条件做")?0xff9b74d4:group.equals("当前可做")?0xff23a684:group.equals("优先做")?0xffd58a21:HyperStyle.accent(a);}
 static String icon(String group){return group.equals("条件做")?"waiting":group.equals("正在做")?"doing":group.equals("优先做")?"priority":"actions";}
 static void render(MainActivity a,LinearLayout parent){
  JSONObject data=Store.read(a,"actions");JSONArray items=data==null?null:data.optJSONArray("items");
  for(String group:GROUPS)a.chip(a.filters,group+"  "+count(items,group),group.equals(a.filter),()->{a.filter=group;a.lastRender="";a.scroll.scrollTo(0,0);a.render();});
  if(items==null){a.empty(parent,"actions","等待事项同步","连接恢复后将在这里显示事项。",()->Store.refresh(a,true,()->a.runOnUiThread(a::render)));return;}
  if(count(items,a.filter)==0){a.empty(parent,"actions","暂无事项","",null);return;}
  String[] sections=a.filter.equals("全部")?new String[]{"正在做","当前可做","条件做"}:new String[]{a.filter};
  for(String group:sections){
   ArrayList<JSONObject> selected=new ArrayList<>();for(int n=0;n<items.length();n++){JSONObject item=items.optJSONObject(n);if(item!=null&&Presentation.inGroup(item,group))selected.add(item);}
   if(selected.isEmpty())continue;
   Collections.sort(selected,(x,y)->Boolean.compare(Presentation.inGroup(y,"优先做"),Presentation.inGroup(x,"优先做")));
   a.section(parent,group,String.valueOf(selected.size()),icon(group),tint(a,group));
   LinearLayout card=DeviceCards.panel(a,parent);card.setPadding(a.dp(16),a.dp(2),a.dp(16),a.dp(2));
   for(int n=0;n<selected.size();n++){if(n>0)a.divider(card,52);row(a,card,selected.get(n),group);}
  }

 }
 static void row(MainActivity a,LinearLayout parent,JSONObject item,String group){
  String id=item.optString("id",item.optString("label"));boolean priority=Presentation.inGroup(item,"优先做");
  LinearLayout wrap=a.column();parent.addView(wrap);LinearLayout head=new LinearLayout(a);head.setGravity(Gravity.CENTER_VERTICAL);head.setPadding(0,a.dp(16),0,a.dp(16));head.setMinimumHeight(a.dp(76));head.setBackground(HyperStyle.press(a,android.graphics.Color.TRANSPARENT,14));HyperStyle.pressMotion(head);wrap.addView(head);
  a.badge(head,priority?"priority":icon(group),priority?tint(a,"优先做"):tint(a,group),36);
  TextView label=a.text(item.optString("label",item.optString("title")).replaceFirst("^\\d{4}\\s+", ""),17,HyperStyle.ink(a));label.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL));label.setPadding(a.dp(14),0,a.dp(8),0);head.addView(label,new LinearLayout.LayoutParams(0,-2,1));
  ImageView arrow=new ImageView(a);arrow.setImageDrawable(HyperStyle.icon(a,"chevron",HyperStyle.muted(a)));head.addView(arrow,new LinearLayout.LayoutParams(a.dp(16),a.dp(20)));
  LinearLayout detail=a.column();detail.setPadding(a.dp(50),0,0,a.dp(18));wrap.addView(detail);
  String next=item.optString("next","");if(!next.isEmpty()){detail.addView(a.text("下一步",13,HyperStyle.muted(a)));TextView value=a.text(next,16,HyperStyle.ink(a));value.setLineSpacing(a.dp(4),1);value.setTextIsSelectable(true);detail.addView(value);}
  String current=item.optString("current","");if(!current.isEmpty()){TextView caption=a.text("当前进度",13,HyperStyle.muted(a));caption.setPadding(0,a.dp(12),0,0);detail.addView(caption);TextView value=a.text(current,15,HyperStyle.muted(a));value.setLineSpacing(a.dp(4),1);value.setTextIsSelectable(true);detail.addView(value);}
  String deadline=item.optString("deadline","");if(!deadline.isEmpty()&&!deadline.equals("无确定期限")&&!deadline.equals("无明确期限"))detail.addView(a.text("期限  "+deadline,14,0xffa45e37));
  boolean open=a.expanded.contains(id);detail.setVisibility(open?View.VISIBLE:View.GONE);arrow.setRotation(open?90:0);head.setContentDescription(label.getText()+"，"+(open?"收起详情":"展开详情"));
  head.setOnClickListener(v->{boolean show=detail.getVisibility()==View.GONE;HyperStyle.expand(parent);if(show)a.expanded.add(id);else a.expanded.remove(id);detail.setVisibility(show?View.VISIBLE:View.GONE);arrow.animate().rotation(show?90:0).setDuration(HyperStyle.motion()?180:0).start();head.setContentDescription(label.getText()+"，"+(show?"收起详情":"展开详情"));});
 }
}
