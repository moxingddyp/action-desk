package com.cxy.workbench;
public final class CardMetricsChecks {
 static int count;
 static void check(boolean ok,String label){count++;if(!ok)throw new AssertionError(label);}
 public static void main(String[] args){
  long now=1780000000000L;
  check(CardMetrics.fresh(now-1000,now,false),"fresh sample accepted");
  check(!CardMetrics.fresh(now-12000,now,false),"12-second sample expired");
  check(!CardMetrics.fresh(0,now,false),"missing sample not online");
  check(!CardMetrics.fresh(now-1000,now,true),"sample issue overrides timestamp");
  check(!CardMetrics.fresh(now+60000,now,false),"large future clock not online");
  check("—".equals(CardMetrics.percent(Double.NaN)),"missing GPU stays unknown");
  check("100%".equals(CardMetrics.percent(120)),"percentage upper bound");
  check("1.0M".equals(CardMetrics.bytes(1048576,true)),"short network units fit small cards");
  check("1.0GB".equals(CardMetrics.bytes(1073741824,false)),"disk capacity units");
  check(!CardMetrics.large(180,140)&&CardMetrics.large(260,240),"size thresholds separate compact/expanded");
  check(CardMetrics.bodyLines(140)>=2&&CardMetrics.bodyLines(1000)<=14,"bounded body lines");
  check(!CardMetrics.nodeFresh(true,"healthy",now-76000,now),"old healthy probe never shows current low delay");
  check(CardMetrics.probeRecent(true,now-1000,now)&&!CardMetrics.nodeFresh(true,"unhealthy",now-1000,now),"recent failed probe distinct from stale");
  check(!CardMetrics.nodeFresh(false,"healthy",now-1000,now),"stale gateway invalidates old selected-node delay");
  System.out.println("CardMetricsChecks passed: "+count);
 }
}
