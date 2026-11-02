package com.cxy.workbench;
public final class ConnectionSpecChecks {
 public static void main(String[] args)throws Exception{
  String[] good={"https://example.com","https://example.com:8443/","http://127.0.0.1:8080","http://[::1]:8080","http://100.64.0.1:18766","http://100.127.255.254"};
  for(String v:good)if(ConnectionSpec.validate(v).isEmpty())throw new AssertionError(v);
  String[] bad={"http://example.com","http://192.0.2.1","http://100.63.0.1","http://100.128.0.1","http://100.64.0.1.evil.test","http://user:pass@127.0.0.1","http://127.0.0.1/path","https://example.com?token=x","https://example.com#x","ftp://example.com","http://127.00.0.1","https://example.com:0"};
  for(String v:bad){try{ConnectionSpec.validate(v);throw new AssertionError(v);}catch(java.io.IOException expected){}}
  System.out.println("ConnectionSpecChecks passed: "+(good.length+bad.length));
 }
}
