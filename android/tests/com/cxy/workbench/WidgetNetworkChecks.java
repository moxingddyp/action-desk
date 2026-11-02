package com.cxy.workbench;
import org.json.*;
public final class WidgetNetworkChecks {
 static int count;static long now=1800000000000L;
 static JSONObject sample(String kind,Boolean online,String protocol,long age)throws Exception{JSONObject p=new JSONObject().put("kind",kind).put("observedAt",(now-age)/1000.0-978307200.0);if(online!=null)p.put("online",online);if(protocol!=null)p.put("transportVersion",protocol);return new JSONObject().put("privateLink",p);}
 static void check(String expected,JSONObject sample)throws Exception{String got=WidgetNetwork.privateLabel(sample,now);if(!expected.equals(got))throw new AssertionError(expected+" != "+got);count++;}
 public static void main(String[] args)throws Exception{
  check("私网直连 · IPv4",sample("direct",true,"IPv4",0));check("私网直连 · IPv6",sample("lan-direct",true,"IPv6",0));check("私网直连",sample("direct",true,"unknown",0));
  check("私网中继",sample("derp",true,"IPv4",0));check("私网中继",sample("peer-relay",true,"IPv6",0));
  check("私网未连接",sample("direct",false,"IPv4",0));check("私网未连接",sample("offline",null,null,0));
  check("私网状态未知",sample("idle",true,null,0));check("私网状态未知",sample("unknown",true,null,0));check("私网状态未知",sample("direct",null,"IPv4",0));check("私网状态未知",sample("direct",true,"IPv6",12000));check("私网状态未知",sample("offline",false,null,12000));check("私网状态未知",null);
  JSONObject failed=sample("direct",true,"IPv4",0);failed.getJSONObject("privateLink").put("error","reader failed");check("私网状态未知",failed);
  JSONObject d=sample("direct",true,"IPv4",0);JSONObject l=new JSONObject().put("state","online").put("observedAt",now/1000.0-978307200.0);d.put("lanLink",l);if(!WidgetNetwork.lanDirect(d,now))throw new AssertionError();count++;l.put("state","unknown");if(WidgetNetwork.lanDirect(d,now))throw new AssertionError();count++;l.put("state","online").put("observedAt",(now-12000)/1000.0-978307200.0);if(WidgetNetwork.lanDirect(d,now))throw new AssertionError();count++;
  if(!WidgetNetwork.privateConnected("私网中继")||WidgetNetwork.privateConnected("私网未连接")||WidgetNetwork.privateConnected("私网状态未知"))throw new AssertionError();count++;
  check("私网在线",sample("unknown",true,null,0).put("id","gateway"));check("私网在线",sample("idle",true,null,0).put("id","gateway"));check("私网未连接",sample("unknown",false,null,0).put("id","gateway"));check("私网状态未知",sample("unknown",null,null,0).put("id","gateway"));check("私网状态未知",sample("unknown",true,null,12000).put("id","gateway"));if(!WidgetNetwork.privateConnected("私网在线"))throw new AssertionError();count++;
  System.out.println("WidgetNetworkChecks passed: "+count);
 }
}
