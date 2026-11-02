package com.cxy.workbench;
/** Shared by Activity and foreground service; no second sampler/timer. */
final class SampleCadence {
 private long last=Long.MIN_VALUE;
 synchronized boolean due(long now){if(last!=Long.MIN_VALUE&&now-last<1000)return false;last=now;return true;}
}
