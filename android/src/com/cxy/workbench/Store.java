package com.cxy.workbench;

import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;
import org.json.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

final class Store {
 static final double FOUNDATION_EPOCH=978307200.0;
 static String baseURL(Context c)throws IOException{return ConnectionSpec.validate(prefs(c).getString("baseURL",""));}
 static final ExecutorService IO=Executors.newSingleThreadExecutor();
 static final AtomicBoolean BUSY=new AtomicBoolean();
 static volatile long lastActionFetch;
 static volatile boolean pageActive;
 static final SampleCadence PHONE_CADENCE=new SampleCadence();
 static volatile long lastCycleElapsed=Long.MIN_VALUE;
 static SharedPreferences prefs(Context c){return c.getSharedPreferences("private_connection",Context.MODE_PRIVATE);}
 static boolean configured(Context c){return !prefs(c).getString("token","").isEmpty();}
 static void importConfig(Context c,Uri uri)throws Exception{
  byte[] b;
  try(InputStream in=c.getContentResolver().openInputStream(uri)){b=limited(in,32768);}
  JSONObject o=new JSONObject(new String(b,StandardCharsets.UTF_8));
  String url=o.getString("baseURL");String token=o.getString("readToken");
  url=ConnectionSpec.validate(url);
  if(token.length()<24||token.length()>512||token.contains("\n")||token.contains("\r"))throw new IOException("连接文件的只读凭据格式不正确");
  if(o.has("macToken")||o.has("actionsToken"))throw new IOException("请导入手机专用连接文件，不使用Mac发布凭据");
  String phone=o.optString("phoneToken","");if(!phone.isEmpty()&&(phone.length()<24||phone.length()>512||phone.contains("\n")||phone.contains("\r")))throw new IOException("手机上报凭据格式不正确");
  prefs(c).edit().putString("token",token).putString("baseURL",url).putString("phoneToken",phone).putString("phoneError","").apply();
  lastActionFetch=0;
 }
 static byte[] limited(InputStream in,int max)throws IOException{
  if(in==null)throw new IOException("文件不可读取");
  ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buf=new byte[8192];int n;
  while((n=in.read(buf))!=-1){if(out.size()+n>max)throw new IOException("响应超出大小限制");out.write(buf,0,n);}return out.toByteArray();
 }
 static JSONObject read(Context c,String name){
  try(FileInputStream in=c.openFileInput(name+".json")){return new JSONObject(new String(limited(in,2000000),StandardCharsets.UTF_8));}
  catch(Exception e){return null;}
 }
 static void cache(Context c,String name,JSONObject o)throws IOException{
  File temp=new File(c.getFilesDir(),name+".tmp");
  try(FileOutputStream out=new FileOutputStream(temp)){out.write(o.toString().getBytes(StandardCharsets.UTF_8));out.getFD().sync();}
  File target=new File(c.getFilesDir(),name+".json");if(!temp.renameTo(target))throw new IOException("展示缓存保存失败");
 }
 static JSONObject get(Context c,String path)throws Exception{
  HttpURLConnection conn=(HttpURLConnection)new URL(baseURL(c)+path).openConnection(Proxy.NO_PROXY);
  conn.setConnectTimeout(3500);conn.setReadTimeout(3500);conn.setInstanceFollowRedirects(false);
  conn.setRequestProperty("Authorization","Bearer "+prefs(c).getString("token",""));
  try{int code=conn.getResponseCode();if(code==503&&path.equals("/v1/actions"))throw new IOException("服务已连接，等待Mac首次同步事项");if(code!=200)throw new IOException("服务响应 HTTP "+code);
   try(InputStream in=conn.getInputStream()){return new JSONObject(new String(limited(in,2000000),StandardCharsets.UTF_8));}
  }finally{conn.disconnect();}
 }
 static void uploadPhone(Context c,JSONObject sample)throws Exception{
  HttpURLConnection conn=(HttpURLConnection)new URL(baseURL(c)+"/v1/phone").openConnection(Proxy.NO_PROXY);
  conn.setConnectTimeout(3500);conn.setReadTimeout(3500);conn.setInstanceFollowRedirects(false);conn.setRequestMethod("PUT");conn.setDoOutput(true);conn.setRequestProperty("Content-Type","application/json");conn.setRequestProperty("Authorization","Bearer "+prefs(c).getString("phoneToken",""));
  try{byte[] body=sample.toString().getBytes(StandardCharsets.UTF_8);conn.setFixedLengthStreamingMode(body.length);try(OutputStream out=conn.getOutputStream()){out.write(body);}int status=conn.getResponseCode();if(status!=200&&status!=201&&status!=204)throw new IOException("手机上报 HTTP "+status);}finally{conn.disconnect();}
 }
 static void refresh(Context context,boolean actions,Runnable after){
  Context c=context.getApplicationContext();
  long elapsed=android.os.SystemClock.elapsedRealtime();
  if(!actions&&lastCycleElapsed!=Long.MIN_VALUE&&elapsed-lastCycleElapsed<1000){if(after!=null)after.run();return;}
  if(!BUSY.compareAndSet(false,true)){if(after!=null)after.run();return;}
  lastCycleElapsed=elapsed;
  IO.execute(()->{
   try{
    if(!configured(c))throw new IOException("请先导入手机连接文件");
    if((pageActive||LiveService.running)&&!prefs(c).getString("phoneToken","").isEmpty()&&PHONE_CADENCE.due(android.os.SystemClock.elapsedRealtime())){
     try{uploadPhone(c,PhoneSampler.sample(c));prefs(c).edit().putString("phoneError","").apply();}
     catch(Exception e){prefs(c).edit().putString("phoneError",e.getMessage()==null?"手机上报失败":e.getMessage()).apply();}
    }
    JSONObject t=get(c,"/v1/telemetry");if(t.optJSONArray("devices")==null)throw new IOException("设备响应格式不正确");cache(c,"telemetry",t);
    if(actions||System.currentTimeMillis()-lastActionFetch>10000||read(c,"actions")==null){
     JSONObject a=get(c,"/v1/actions");if(a.optJSONArray("items")==null)throw new IOException("行动台还没有可读取的同步数据");cache(c,"actions",a);lastActionFetch=System.currentTimeMillis();
    }
    prefs(c).edit().putString("error","").putLong("lastFetch",System.currentTimeMillis()).apply();
   }catch(Exception e){prefs(c).edit().putString("error",e instanceof UnknownHostException?"无法解析私网服务":e instanceof SocketTimeoutException?"服务连接超时，请确认网络与服务在线":e instanceof ConnectException?"无法连接服务，请确认网络可达":e.getMessage()==null?"获取失败":e.getMessage()).apply();}
   finally{BUSY.set(false);Widgets.updateAll(c);if(after!=null)after.run();}
  });
 }
 static long sampleMillis(JSONObject o,String field){return o==null||!o.has(field)||o.isNull(field)?0:(long)((o.optDouble(field,0)+FOUNDATION_EPOCH)*1000);}
 static String stamp(long time){return time<=0?"暂无记录":new java.text.SimpleDateFormat("MM-dd HH:mm:ss",java.util.Locale.CHINA).format(new java.util.Date(time));}
 static String err(Context c){return prefs(c).getString("error","");}
}
