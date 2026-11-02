package com.cxy.workbench;
import org.json.JSONObject;
import java.io.*;
import java.nio.file.Files;
public final class UpdateSpecChecks {
 static int count;
 static JSONObject valid()throws Exception{return new JSONObject().put("packageName","com.cxy.workbench").put("versionCode",6).put("versionName","1.4.0").put("size",3).put("sha256","ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad").put("certSHA256",repeat('a',64)).put("downloadPath","/v1/app-updates/android/apk/6/ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad.apk");}
 static String repeat(char c,int n){StringBuilder b=new StringBuilder();for(int i=0;i<n;i++)b.append(c);return b.toString();}
 static void reject(String key,Object value)throws Exception{JSONObject j=valid();j.put(key,value);try{new UpdateSpec(j);throw new AssertionError(key);}catch(IOException expected){count++;}}
 public static void main(String[] a)throws Exception{
  UpdateSpec r=new UpdateSpec(valid());if(r.version!=6||r.size!=3)throw new AssertionError();count++;
  reject("packageName","another.app");reject("versionCode",0);reject("size",0);reject("size",67108865);reject("sha256",repeat('A',64));reject("certSHA256","bad");reject("versionName","");reject("versionName",repeat('a',81));
  for(String p:new String[]{"https://example.com/update.apk","//example.com/a","/v1/app-updates/android/apk/6/../x","/v1/app-updates/android/apk/7/"+r.sha+".apk",r.path+"?token=x",r.path+"#x"})reject("downloadPath",p);
  File f=File.createTempFile("workbench-update-check",".apk");try{Files.write(f.toPath(),new byte[]{97,98,99});UpdateSpec.verifyFile(f,3,r.sha);count++;try{UpdateSpec.verifyFile(f,2,r.sha);throw new AssertionError();}catch(IOException e){count++;}try{UpdateSpec.verifyFile(f,3,repeat('a',64));throw new AssertionError();}catch(IOException e){count++;}}finally{f.delete();}
  System.out.println("UpdateSpecChecks passed: "+count);
 }
}
