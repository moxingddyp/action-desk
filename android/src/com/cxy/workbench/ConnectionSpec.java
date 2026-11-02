package com.cxy.workbench;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;

/** Accept HTTPS, or HTTP only for literal loopback/CGNAT private-network hosts. */
final class ConnectionSpec {
 static String validate(String value)throws IOException {
  try {
   URI u=new URI(value);
   String host=u.getHost(), scheme=u.getScheme();
   if(host==null||u.getRawUserInfo()!=null||u.getRawQuery()!=null||u.getRawFragment()!=null||!"".equals(u.getRawPath())&& !"/".equals(u.getRawPath())||u.getPort()==0||u.getPort()>65535)throw new IOException("连接地址格式不正确");
   if(!"https".equals(scheme)&&!("http".equals(scheme)&&privateHTTP(host)))throw new IOException("连接需HTTPS，HTTP仅允许回环或CGNAT私网IP");
   return value.endsWith("/")?value.substring(0,value.length()-1):value;
  }catch(URISyntaxException e){throw new IOException("连接地址格式不正确");}
 }
 static boolean privateHTTP(String host){
  if("[::1]".equals(host)||"::1".equals(host))return true;
  String[] parts=host.split("\\.",-1);if(parts.length!=4)return false;
  int[] n=new int[4];for(int i=0;i<4;i++){if(!parts[i].matches("0|[1-9][0-9]{0,2}"))return false;n[i]=Integer.parseInt(parts[i]);if(n[i]>255)return false;}
  return n[0]==127||n[0]==100&&n[1]>=64&&n[1]<=127;
 }
}
