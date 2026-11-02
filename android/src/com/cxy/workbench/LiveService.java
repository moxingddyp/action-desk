package com.cxy.workbench;
import android.app.*;
import android.content.*;
import android.content.pm.ServiceInfo;
import android.os.*;

public final class LiveService extends Service {
 static volatile boolean running;
 final Handler handler=new Handler(Looper.getMainLooper());
 final Runnable tick=new Runnable(){public void run(){if(running){Store.refresh(LiveService.this,false,null);handler.postDelayed(this,1000);}}};
 @Override public void onCreate(){super.onCreate();}
 @Override public int onStartCommand(Intent intent,int flags,int id){
  if(intent!=null&&"stop".equals(intent.getAction())){stopSelf();return START_NOT_STICKY;}
  NotificationManager n=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);
  n.createNotificationChannel(new NotificationChannel("live","设备小组件实时更新",NotificationManager.IMPORTANCE_LOW));
  Notification notice=new Notification.Builder(this,"live").setSmallIcon(android.R.drawable.ic_menu_view).setContentTitle("CXY 小组件实时更新中").setContentText("应用运行期间更新桌面；划掉应用后停止。").setOngoing(true).setContentIntent(Widgets.activity(this,"devices")).build();
  if(Build.VERSION.SDK_INT>=29)startForeground(40,notice,ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);else startForeground(40,notice);
  if(!running){running=true;handler.post(tick);}return START_NOT_STICKY;
 }
 @Override public void onTimeout(int startId,int fgsType){stopSelf();}
 @Override public void onDestroy(){running=false;handler.removeCallbacks(tick);stopForeground(STOP_FOREGROUND_REMOVE);super.onDestroy();}
 @Override public IBinder onBind(Intent i){return null;}
}
