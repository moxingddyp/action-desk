package com.cxy.workbench;
import java.util.Locale;
final class CardMetrics {
 static boolean fresh(long sampledAt,long now,boolean issue){return sampledAt>0&&now-sampledAt<12000&&now-sampledAt>=-30000&&!issue;}
 static String percent(double n){return Double.isNaN(n)||Double.isInfinite(n)?"—":String.format(Locale.CHINA,"%.0f%%",Math.max(0,Math.min(100,n)));}
 static String bytes(double n,boolean rate){if(Double.isNaN(n)||Double.isInfinite(n)||n<0)return "—";String[] units=rate?new String[]{"B","K","M","G"}:new String[]{"B","KB","MB","GB","TB"};int i=0;while(n>=1024&&i<units.length-1){n/=1024;i++;}return String.format(Locale.CHINA,i==0?"%.0f%s":"%.1f%s",n,units[i]);}
 static boolean large(int width,int height){return width>=220&&height>=220;}
 static int bodyLines(int height){return Math.max(2,Math.min(14,(height-75)/16));}
 static boolean probeRecent(boolean deviceFresh,long probeAt,long now){return deviceFresh&&probeAt>0&&now-probeAt<75000&&now-probeAt>=-30000;}
 static boolean nodeFresh(boolean deviceFresh,String health,long probeAt,long now){return "healthy".equals(health)&&probeRecent(deviceFresh,probeAt,now);}
}
