package com.cxy.workbench;
import android.appwidget.AppWidgetProvider;
import android.content.*;
public final class MacWidget extends AppWidgetProvider {
 @Override public void onReceive(Context c,Intent i){super.onReceive(c,i);Widgets.receive(this,c,i);}
}
