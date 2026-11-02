package com.cxy.workbench;
import org.json.*;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.util.*;

public final class PainterChecks {
 static int checks;
 static void check(boolean result,String message){checks++;if(!result)throw new AssertionError(message);}
 static final class Tape implements CardPainter.Surface {
  final java.util.List<String> texts=new ArrayList<>();final java.util.List<float[]> bounds=new ArrayList<>();final java.util.List<int[]> points=new ArrayList<>();final Graphics2D g=new BufferedImage(4,4,BufferedImage.TYPE_INT_ARGB).createGraphics();
  public void rect(float a,float b,float c,float d,float r,int color){}public void line(float a,float b,float c,float d,float e,int f){}public void glow(float a,float b,float c,int d){}public void arc(float a,float b,float c,float d,float e,float f,int color){}
  public void circle(float a,float b,float r,int color){points.add(new int[]{Math.round(a),Math.round(b),color});}
  public void text(String s,float x,float y,float z,int color,boolean bold){texts.add(s);bounds.add(new float[]{x,y,measure(s,z,bold)});}
  public float measure(String s,float z,boolean bold){return (float)new Font("SansSerif",bold?Font.BOLD:Font.PLAIN,12).deriveFont(z).getStringBounds(s,g.getFontRenderContext()).getWidth();}
 }
 static JSONObject sample(String kind,long now)throws Exception{double epoch=now/1000.0-978307200;JSONObject d=new JSONObject().put("id",kind).put("host",kind).put("receivedAt",epoch).put("cpu",30).put("gpu",7).put("memoryUsed",8L*1024*1024*1024).put("memoryTotal",16L*1024*1024*1024).put("download",32000).put("upload",9000).put("batteryPercent",39).put("onACPower",false).put("hardwareFresh",true).put("hardwareSampleAvailable",true);d.put("lanLink",new JSONObject().put("state","online").put("observedAt",epoch));d.put("privateLink",new JSONObject().put("kind","direct").put("online",true).put("active",true).put("transportVersion","IPv6").put("observedAt",epoch));JSONArray disks=new JSONArray();for(int i=0;i<4;i++)disks.put(new JSONObject().put("name",i==0?"系统盘":"Very Long External Drive Name "+i).put("total",2000000000000L).put("used",400000000000L));d.put("disks",disks);return d;}
 public static void main(String[] args)throws Exception{
  long now=1780000000000L;JSONObject mac=sample("mac",now),phone=sample("phone",now),linux=sample("linux",now),snapshot=new JSONObject().put("devices",new JSONArray().put(mac).put(linux)).put("phone",phone);
  Tape tape=new Tape();CardPainter.device(tape,snapshot,"mac",now,170,false);check(tape.texts.contains("局域网在线")&&tape.texts.contains("私网在线"),"independent LAN and private membership both shown");boolean blue=false,green=false;for(int[] p:tape.points){if(p[0]==231&&p[1]==23&&p[2]==CardPainter.BLUE)blue=true;if(p[0]==299&&p[1]==23&&p[2]==CardPainter.GREEN)green=true;}check(blue&&green,"LAN dot blue, private dot green");
  mac.getJSONObject("lanLink").put("state","offline");tape=new Tape();CardPainter.device(tape,snapshot,"mac",now,170,false);check(!tape.texts.contains("局域网在线")&&!tape.texts.contains("局域网离线")&&tape.texts.contains("私网在线"),"away header only private membership");
  check(CardPainter.rate(Double.NaN,true).equals("—")&&CardPainter.rate(32000,false).equals("—"),"missing/stale speeds never show —/s");check(CardPainter.rate(32000,true).contains("KB/s"),"real speed unit KB/s");
  phone.remove("cpu");phone.remove("gpu");phone.remove("download");phone.remove("upload");tape=new Tape();CardPainter.device(tape,snapshot,"phone",now,170,false);check(tape.texts.contains("—"),"phone unavailable metrics remain missing");check(tape.texts.stream().noneMatch(s->s.equals("—/s")),"phone whole-device speed not invented");
  phone.getJSONObject("privateLink").put("kind","derp").remove("transportVersion");tape=new Tape();CardPainter.device(tape,snapshot,"phone",now,170,false);check(tape.texts.stream().anyMatch(s->s.contains("协议未提供")),"relay outer protocol unknown");
  tape=new Tape();CardPainter.device(tape,null,"mac",now,170,true);check(tape.texts.contains("私网未知")&&!tape.texts.contains("局域网未知"),"missing LAN omitted, private state unknown");
  for(int total=0;total<=34;total++){int[] colors=ActionPainter.colors(total);check(colors.length==total,"ring count "+total);int outer=ActionPainter.outerCount(total);for(int n=0;n<total;n++){int count=n<outer?outer:total-outer,local=n<outer?n:n-outer;if(count>1){int next=n<outer?(local+1)%count:outer+(local+1)%count;check(colors[n]!=colors[next],"adjacent colors distinct "+total);}}}
  JSONArray items=new JSONArray();for(int i=0;i<34;i++)items.put(new JSONObject().put("id","item"+i).put("label","超长论文事项标题需要截断展示 "+i).put("next","一个具体的下一步，保持分类事实和现有来源").put("tags",new JSONArray().put("优先做")).put("projects",new JSONArray().put("0003")));
  JSONObject actions=new JSONObject().put("items",items).put("calendarEvents",new JSONArray()).put("generatedAt","2026-10-31T08:00:00Z");tape=new Tape();java.util.List<ActionPainter.Hit> hits=ActionPainter.draw(tape,actions,0,"ring",0,"",470,false);check(tape.texts.stream().anyMatch(s->s.contains("16:00:00")),"source time converted to Asia/Shanghai");java.util.List<ActionPainter.Hit> sectors=new ArrayList<>();for(ActionPainter.Hit hit:hits)if(hit.action.equals("select")&&hit.y<380)sectors.add(hit);for(int i=0;i<sectors.size();i++)for(int j=i+1;j<sectors.size();j++){ActionPainter.Hit a=sectors.get(i),b=sectors.get(j);check(Math.min(a.x+a.w,b.x+b.w)-Math.max(a.x,b.x)<.001||Math.min(a.y+a.h,b.y+b.h)-Math.max(a.y,b.y)<.001,"ring hit rectangles do not overlap");}
  tape=new Tape();ActionPainter.draw(tape,actions,0,"list",0,"",470,false);check(tape.texts.stream().anyMatch(s->s.equals("1 / 6")),"list pagination uses actual capacity");
  System.out.println("PainterChecks passed: "+checks);
 }
}
