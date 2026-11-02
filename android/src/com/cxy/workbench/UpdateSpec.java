package com.cxy.workbench;
import org.json.JSONObject;
import java.io.*;
import java.util.Locale;
import java.security.MessageDigest;

/** Strict release metadata and content-integrity boundary, independent of UI. */
final class UpdateSpec {
 final long version,size;final String name,sha,cert,path;
 UpdateSpec(JSONObject j)throws Exception{
  version=j.getLong("versionCode");size=j.getLong("size");name=j.getString("versionName");sha=j.getString("sha256");cert=j.getString("certSHA256");path=j.getString("downloadPath");
  if(!"com.cxy.workbench".equals(j.getString("packageName"))||version<1||size<1||size>64L*1024*1024||name.isEmpty()||name.length()>80||!sha.matches("[0-9a-f]{64}")||!cert.matches("[0-9a-f]{64}"))throw new IOException("更新清单的应用或版本格式无效");
  if(!path.equals("/v1/app-updates/android/apk/"+version+"/"+sha+".apk"))throw new IOException("更新清单的下载位置不匹配");
 }
 static void verifyFile(File file,long size,String hash)throws Exception{
  if(file.length()!=size)throw new IOException("安装包大小校验失败");MessageDigest digest=MessageDigest.getInstance("SHA-256");try(InputStream in=new FileInputStream(file)){byte[] b=new byte[32768];int n;while((n=in.read(b))!=-1)digest.update(b,0,n);}StringBuilder s=new StringBuilder();for(byte v:digest.digest())s.append(String.format(Locale.ROOT,"%02x",v&255));if(!s.toString().equals(hash))throw new IOException("安装包SHA256校验失败");
 }
}
