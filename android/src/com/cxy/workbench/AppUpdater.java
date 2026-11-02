package com.cxy.workbench;

import android.app.*;
import android.content.*;
import android.content.pm.*;
import android.net.Uri;
import android.provider.Settings;
import org.json.JSONObject;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** User-triggered updates over the existing authenticated private service only. */
final class AppUpdater {
 static final String MANIFEST="/v1/app-updates/android";
 static final int STATUS_ID=0x00c07801;
 static final long MAX_SIZE=64L*1024*1024;
 static final AtomicBoolean BUSY=new AtomicBoolean();
 static void check(Activity a){
  if(!Store.configured(a)){message(a,"请先导入手机连接文件");return;}
  if(!BUSY.compareAndSet(false,true)){message(a,"正在检查或下载更新");return;}
  message(a,"正在检查更新…");
  new Thread(()->{try{
   HttpURLConnection c=connect(a,MANIFEST);JSONObject j;
   try{int code=c.getResponseCode();if(code==404||code==503){message(a,"更新服务暂未发布安装包");return;}if(code!=200)throw new IOException("检查更新 HTTP "+code);try(InputStream in=c.getInputStream()){j=new JSONObject(new String(Store.limited(in,16384),StandardCharsets.UTF_8));}}finally{c.disconnect();}
   UpdateSpec r=new UpdateSpec(j);long current=a.getPackageManager().getPackageInfo(a.getPackageName(),0).getLongVersionCode();
   if(r.version<=current){message(a,"已是最新版本 "+a.getPackageManager().getPackageInfo(a.getPackageName(),0).versionName);return;}
   a.runOnUiThread(()->{if(a.isFinishing()||a.isDestroyed())return;new AlertDialog.Builder(a).setTitle("发现更新 "+r.name).setMessage("下载 "+String.format(Locale.ROOT,"%.1f MB",r.size/1048576.0)+"，验证完整性和本应用签名后交给系统确认安装。当前数据与连接配置保留。").setNegativeButton("取消",null).setPositiveButton("下载并更新",(d,w)->download(a,r)).show();});
  }catch(Exception e){message(a,"检查更新失败："+safe(e));}finally{BUSY.set(false);}},"workbench-update-check").start();
 }
 static HttpURLConnection connect(Context a,String path)throws Exception{
  if(!MANIFEST.equals(path)&&!path.matches("/v1/app-updates/android/apk/[1-9][0-9]*/[0-9a-f]{64}\\.apk"))throw new IOException("更新路径未获允许");
  HttpURLConnection c=(HttpURLConnection)new URL(Store.baseURL(a)+path).openConnection(Proxy.NO_PROXY);c.setInstanceFollowRedirects(false);c.setConnectTimeout(5000);c.setReadTimeout(20000);c.setRequestProperty("Authorization","Bearer "+Store.prefs(a).getString("token",""));return c;
 }
 static File file(Context c){return new File(c.getCacheDir(),"workbench-update.apk");}
 static void download(Activity a,UpdateSpec r){
  if(!BUSY.compareAndSet(false,true))return;message(a,"正在下载更新…");
  new Thread(()->{File tmp=new File(a.getCacheDir(),"workbench-update.part");boolean good=false;try{
   HttpURLConnection c=connect(a,r.path);MessageDigest digest=MessageDigest.getInstance("SHA-256");long total=0;
   try{if(c.getResponseCode()!=200)throw new IOException("下载安装包 HTTP "+c.getResponseCode());long declared=c.getContentLengthLong();if(declared>=0&&declared!=r.size)throw new IOException("安装包响应大小与清单不一致");
    try(InputStream in=c.getInputStream();FileOutputStream out=new FileOutputStream(tmp)){byte[] buf=new byte[32768];int n;while((n=in.read(buf))!=-1){total+=n;if(total>r.size)throw new IOException("安装包超出清单大小");digest.update(buf,0,n);out.write(buf,0,n);}out.getFD().sync();}
   }finally{c.disconnect();}
   if(total!=r.size||!hex(digest.digest()).equals(r.sha))throw new IOException("安装包大小或SHA256校验失败");
   validate(a,tmp,r);File target=file(a);if(target.exists()&&!target.delete())throw new IOException("旧安装缓存无法替换");if(!tmp.renameTo(target))throw new IOException("安装缓存保存失败");good=true;
   a.runOnUiThread(()->{if(!a.isFinishing()&&!a.isDestroyed())install(a,r);});
  }catch(Exception e){message(a,"更新失败："+safe(e));}finally{if(!good)tmp.delete();BUSY.set(false);}},"workbench-update-download").start();
 }
 static void validate(Context c,File f,UpdateSpec r)throws Exception{
  PackageManager pm=c.getPackageManager();PackageInfo archive=pm.getPackageArchiveInfo(f.getAbsolutePath(),PackageManager.GET_SIGNING_CERTIFICATES),installed=pm.getPackageInfo(c.getPackageName(),PackageManager.GET_SIGNING_CERTIFICATES);
  if(archive==null||!c.getPackageName().equals(archive.packageName)||archive.getLongVersionCode()!=r.version||!r.name.equals(archive.versionName)||r.version<=installed.getLongVersionCode())throw new IOException("安装包应用或版本不匹配");
  if(installed.signingInfo==null||!signatures(installed.signingInfo.getApkContentsSigners()).equals(java.util.Collections.singleton(r.cert)))throw new IOException("更新清单签名与当前应用不一致");
  if(archive.signingInfo==null||installed.signingInfo==null||!signatures(archive.signingInfo.getApkContentsSigners()).equals(signatures(installed.signingInfo.getApkContentsSigners())))throw new IOException("安装包签名与当前应用不一致");
 }
 static Set<String> signatures(Signature[] values)throws Exception{Set<String>s=new TreeSet<>();if(values==null||values.length==0)throw new IOException("缺少应用签名");for(Signature v:values)s.add(hex(MessageDigest.getInstance("SHA-256").digest(v.toByteArray())));return s;}
 static void install(Activity a,UpdateSpec r){try{
  File f=file(a);UpdateSpec.verifyFile(f,r.size,r.sha);validate(a,f,r);
  if(!a.getPackageManager().canRequestPackageInstalls()){
   new AlertDialog.Builder(a).setTitle("允许本应用请求更新安装").setMessage("系统需要你允许“CXY 工作台”安装未知来源应用。只打开本应用对应开关，返回后再次点击“检查更新”。不会静默安装。").setNegativeButton("取消",null).setPositiveButton("打开系统设置",(d,w)->{try{a.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,Uri.parse("package:"+a.getPackageName())));}catch(RuntimeException e){message(a,"无法打开安装授权设置："+safe(e));}}).show();return;
  }
  Uri uri=Uri.parse("content://"+a.getPackageName()+".updates/workbench-update.apk");
  Intent i=new Intent(Intent.ACTION_VIEW).setDataAndType(uri,"application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);i.setClipData(ClipData.newRawUri("安装更新",uri));a.startActivity(i);
 }catch(Exception e){message(a,"无法请求系统安装："+safe(e));}}
 static String hex(byte[] b){StringBuilder s=new StringBuilder();for(byte v:b)s.append(String.format(Locale.ROOT,"%02x",v&255));return s.toString();}
 static String safe(Exception e){return e instanceof IOException?e.getMessage():e.getClass().getSimpleName();}
 static void message(Activity a,String s){a.runOnUiThread(()->{if(a.isFinishing()||a.isDestroyed())return;android.widget.TextView status=a.findViewById(STATUS_ID);if(status!=null)status.setText(s);android.widget.Toast.makeText(a,s,android.widget.Toast.LENGTH_LONG).show();});}
}
