package com.cxy.workbench;
import android.app.*;
import android.content.*;
import android.content.res.*;
import android.graphics.*;
import android.graphics.drawable.*;
import android.view.*;
import android.widget.*;

/** HyperOS-inspired native presentation. Reference: Miuix, pinned in the design receipt. */
final class HyperStyle {
 static boolean dark(Context c){return (c.getResources().getConfiguration().uiMode&Configuration.UI_MODE_NIGHT_MASK)==Configuration.UI_MODE_NIGHT_YES;}
 static int accent(Context c){return dark(c)?0xff78a4ff:0xff3482ff;}
 static int background(Context c){return dark(c)?0xff000000:0xfff7f7f7;}
 static int surface(Context c){return dark(c)?0xff242424:Color.WHITE;}
 static int ink(Context c){return dark(c)?0xfff2f2f2:0xff101010;}
 static int muted(Context c){return dark(c)?0xffa4a4a4:0xff7b7b7b;}
 static int soft(Context c){return dark(c)?0xff303030:0xffededed;}
 static int wash(Context c){return dark(c)?0xff263751:0xffeaf2ff;}
 static int color(Context c,int old){switch(old){case 0xff087bfa:case 0xff1680ff:case 0xff176dce:case 0xff0575ff:return accent(c);case 0xff19212e:case 0xff18334f:case 0xff183b64:case 0xff31475b:case 0xff314f6d:return ink(c);case 0xff354256:case 0xff536b82:return dark(c)?0xffd4d4d4:0xff454545;case 0xff657184:case 0xff77818f:case 0xff6d7f92:case 0xff60748a:case 0xff6b7f91:case 0xff7b8c9d:case 0xff7a8c9f:return muted(c);default:return old;}}
 static GradientDrawable shape(Context c,int color,int radius){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(DeviceCards.dp(c,radius));return d;}
 static Drawable press(Context c,int color,int radius){return new RippleDrawable(ColorStateList.valueOf(dark(c)?0x20ffffff:0x10000000),shape(c,color,radius),shape(c,Color.WHITE,radius));}
 static Context dialogContext(Context c){return new ContextThemeWrapper(c,dark(c)?android.R.style.Theme_Material_Dialog_Alert:android.R.style.Theme_Material_Light_Dialog_Alert);}
 static void dialog(AlertDialog d){d.setOnShowListener(v->{if(d.getWindow()!=null)d.getWindow().setBackgroundDrawable(shape(d.getContext(),surface(d.getContext()),26));for(int b:new int[]{-1,-2,-3})if(d.getButton(b)!=null)d.getButton(b).setTextColor(accent(d.getContext()));});d.show();}
 static Drawable icon(Context c,String name,int color){return new Icon(c,name,color);}
 static boolean motion(){return android.animation.ValueAnimator.areAnimatorsEnabled();}
 static void enter(View view){if(!motion())return;view.animate().cancel();view.setAlpha(0);view.setTranslationY(DeviceCards.dp(view.getContext(),10));view.animate().alpha(1).translationY(0).setDuration(190).setInterpolator(new android.view.animation.DecelerateInterpolator()).start();}
 static void pressMotion(View view){view.setOnTouchListener((v,event)->{if(motion()){if(event.getActionMasked()==MotionEvent.ACTION_DOWN)v.animate().scaleX(.98f).scaleY(.98f).setDuration(90).start();else if(event.getActionMasked()==MotionEvent.ACTION_UP||event.getActionMasked()==MotionEvent.ACTION_CANCEL)v.animate().scaleX(1).scaleY(1).setDuration(180).setInterpolator(new android.view.animation.OvershootInterpolator(.8f)).start();}return false;});}
 static void expand(ViewGroup group){if(motion())android.transition.TransitionManager.beginDelayedTransition(group,new android.transition.AutoTransition().setDuration(180));}
 static final class Icon extends Drawable {
  final Paint p=new Paint(3);final String name;final int color;final Context context;int opacity=255;
  Icon(Context c,String n,int col){context=c;name=n;color=col;}
  public int getIntrinsicWidth(){return DeviceCards.dp(context,24);}public int getIntrinsicHeight(){return DeviceCards.dp(context,24);}
  public void draw(Canvas c){c.save();Rect b=getBounds();c.translate(b.left,b.top);c.scale(b.width()/24f,b.height()/24f);p.setColor(color);p.setAlpha(opacity);p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(1.8f);p.setStrokeCap(Paint.Cap.ROUND);p.setStrokeJoin(Paint.Join.ROUND);
   if(name.equals("calendar")){c.drawRoundRect(3,5,21,21,3,3,p);c.drawLine(3,10,21,10,p);c.drawLine(8,3,8,7,p);c.drawLine(16,3,16,7,p);c.drawCircle(8,14,1,p);c.drawCircle(13,14,1,p);c.drawCircle(8,18,1,p);}
   else if(name.equals("close")){c.drawLine(6,6,18,18,p);c.drawLine(18,6,6,18,p);}
   else if(name.equals("mac")){c.drawRoundRect(5,3,19,16,2,2,p);c.drawLine(5,16,2,20,p);c.drawLine(2,20,22,20,p);c.drawLine(22,20,19,16,p);}
   else if(name.equals("phone")){c.drawRoundRect(6,2,18,22,3,3,p);c.drawLine(10,5,14,5,p);c.drawLine(10,19,14,19,p);}
   else if(name.equals("linux")||name.equals("gateway")){c.drawRoundRect(3,3,21,21,2,2,p);c.drawLine(3,9,21,9,p);c.drawLine(3,15,21,15,p);c.drawCircle(7,6,1,p);c.drawCircle(7,12,1,p);c.drawCircle(7,18,1,p);c.drawLine(12,6,17,6,p);c.drawLine(12,12,17,12,p);c.drawLine(12,18,17,18,p);}
   else if(name.equals("disk")){c.drawRoundRect(3,4,21,20,3,3,p);c.drawLine(4,15,20,15,p);c.drawCircle(17,17.5f,.7f,p);}
   else if(name.equals("globe")){c.drawCircle(12,12,9,p);c.drawOval(8,3,16,21,p);c.drawLine(3,12,21,12,p);}
   else if(name.equals("business")){c.drawRoundRect(3,7,21,21,2,2,p);c.drawRoundRect(8,3,16,7,1,1,p);c.drawLine(3,12,21,12,p);c.drawLine(10,12,14,12,p);}
   else if(name.equals("actions")){c.drawRoundRect(4,3,20,21,3,3,p);c.drawLine(8,8,10,8,p);c.drawLine(13,8,16,8,p);c.drawLine(8,12,10,12,p);c.drawLine(13,12,16,12,p);c.drawLine(8,16,10,16,p);c.drawLine(13,16,16,16,p);}
   else if(name.equals("devices")||name.equals("winpc")){c.drawRoundRect(3,4,21,16,2,2,p);c.drawLine(12,16,12,20,p);c.drawLine(8,20,16,20,p);}
   else if(name.equals("news")){c.drawRoundRect(3,3,21,21,2,2,p);c.drawLine(8,3,8,21,p);c.drawLine(12,8,17,8,p);c.drawLine(12,12,17,12,p);c.drawLine(12,16,15,16,p);}
   else if(name.equals("priority")){Path star=new Path();for(int i=0;i<10;i++){double a=-Math.PI/2+i*Math.PI/5;float r=i%2==0?9:4;float x=12+(float)Math.cos(a)*r,y=12+(float)Math.sin(a)*r;if(i==0)star.moveTo(x,y);else star.lineTo(x,y);}star.close();c.drawPath(star,p);}
   else if(name.equals("doing")){c.drawCircle(12,12,9,p);Path play=new Path();play.moveTo(10,8);play.lineTo(16,12);play.lineTo(10,16);play.close();c.drawPath(play,p);}
   else if(name.equals("waiting")){c.drawCircle(12,12,9,p);c.drawLine(12,7,12,12,p);c.drawLine(12,12,16,14,p);}
   else if(name.equals("chevron")){c.drawLine(9,5,16,12,p);c.drawLine(16,12,9,19,p);}
   else if(name.equals("link")){c.drawLine(6,18,18,6,p);c.drawLine(10,6,18,6,p);c.drawLine(18,6,18,14,p);}
   else if(name.equals("book")){c.drawRoundRect(4,3,20,21,2,2,p);c.drawLine(8,3,8,21,p);c.drawLine(12,8,16,8,p);c.drawLine(12,12,16,12,p);}
   else if(name.equals("refresh")){c.drawArc(4,4,20,20,45,285,false,p);c.drawLine(20,4,20,10,p);c.drawLine(20,10,14,10,p);}
   else if(name.equals("back")){c.drawLine(15,5,8,12,p);c.drawLine(8,12,15,19,p);}
   else if(name.equals("widgets")){for(int x=4;x<18;x+=10)for(int y=4;y<18;y+=10)c.drawRoundRect(x,y,x+6,y+6,1.5f,1.5f,p);}
   else if(name.equals("import")){c.drawRoundRect(5,3,19,21,2,2,p);c.drawLine(12,7,12,15,p);c.drawLine(9,12,12,15,p);c.drawLine(12,15,15,12,p);}
   else {c.drawCircle(12,12,3,p);for(int n=0;n<8;n++){double a=n*Math.PI/4;c.drawLine(12+(float)Math.cos(a)*7,12+(float)Math.sin(a)*7,12+(float)Math.cos(a)*9,12+(float)Math.sin(a)*9,p);}c.drawCircle(12,12,7,p);}
   c.restore();}
  public void setAlpha(int a){opacity=a;}public void setColorFilter(ColorFilter f){p.setColorFilter(f);}public int getOpacity(){return PixelFormat.TRANSLUCENT;}
 }
}
