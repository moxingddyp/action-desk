package com.cxy.workbench;
import org.json.*;
public final class DeviceTextChecks {
 static int count;
 static void check(boolean value,String label){count++;if(!value)throw new AssertionError(label);}
 static JSONObject object(String s)throws Exception{return new JSONObject(s);}
 public static void main(String[]args)throws Exception{
  long now=1780000000000L;double date=now/1000.0-978307200.0;
  JSONObject phone=object("{\"id\":\"phone\",\"hardwareSampleAvailable\":false,\"hardwareFresh\":false}");
  phone.put("privateLink",object("{\"online\":true,\"active\":true,\"kind\":\"direct\",\"transportVersion\":\"IPv6\"}").put("observedAt",date));
  check(!DeviceText.hardwareFresh(phone,now),"network presence does not invent phone hardware freshness");
  check(DeviceText.link(phone,now).contains("直连")&&DeviceText.link(phone,now).contains("IPv6"),"actual direct IPv6 displayed");
  phone.getJSONObject("privateLink").put("kind","derp").remove("transportVersion");
  check(DeviceText.link(phone,now).contains("中继")&&DeviceText.link(phone,now).contains("协议未提供"),"relay transport not guessed from tailnet IPv4");
  phone.getJSONObject("privateLink").put("observedAt",date-20);
  check(DeviceText.link(phone,now).contains("待更新"),"stale private link hidden");
  phone.put("receivedAt",date).put("hardwareSampleAvailable",true).put("hardwareFresh",true);
  check(DeviceText.hardwareFresh(phone,now),"real phone sample with server freshness accepted");
  phone.put("hardwareFresh",false);check(!DeviceText.hardwareFresh(phone,now),"server-expired hardware respected");
  phone.put("batteryPercent",0).put("onACPower",false);check(DeviceText.battery(phone).contains("0%"),"zero battery is real value not missing");
  check(DeviceText.battery(object("{}")).contains("未提供"),"missing battery not fabricated");
  JSONObject power=object("{\"batteryPercent\":80}");check(DeviceText.battery(power).contains("供电状态未提供"),"unknown AC state not guessed as battery");
  power.put("batteryCharging",true);check(DeviceText.battery(power).contains("充电"),"charging label");
  JSONObject mac=object("{\"id\":\"mac\",\"memoryTotal\":16000,\"memoryUsed\":8000}").put("receivedAt",date);
  check(DeviceText.hardwareFresh(mac,now)&&DeviceText.memory(mac).equals("50%"),"Mac memory/freshness");
  mac.put("receivedAt",date-12);check(!DeviceText.hardwareFresh(mac,now),"Mac 12s timeout");
  JSONObject snapshot=new JSONObject().put("devices",new JSONArray().put(mac)).put("phone",phone);
  check(DeviceText.sample(snapshot,"phone")==phone&&DeviceText.sample(snapshot,"mac")==mac,"top-level phone distinct from devices array");
  check(DeviceText.network(object("{\"networkType\":\"vpn\"}")).equals("系统VPN"),"actual active VPN network type");
  check(DeviceText.network(object("{}")).contains("未提供"),"missing physical network not guessed");
  JSONObject disk=object("{\"name\":\"F:\",\"total\":1073741824,\"used\":536870912}");check(DeviceText.diskLine(disk).contains("50%")&&DeviceText.diskLine(disk).contains("F:"),"disk identity and capacity preserved");
  check(Double.isNaN(DeviceText.number(phone,"cpu"))&&Double.isNaN(DeviceText.number(phone,"download")),"unprovided phone CPU and throughput absent");
  SampleCadence cadence=new SampleCadence();int accepted=0;for(long tick=0;tick<10000;tick+=250)if(cadence.due(tick))accepted++;check(accepted==10,"two staggered timer callers still sample once per second");
  check(!cadence.due(9250),"manual refresh cannot duplicate phone sample within a second");
  System.out.println("DeviceTextChecks passed: "+count);
 }
}
