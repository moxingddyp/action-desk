package com.cxy.workbench;
import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.*;
import android.view.View;
import java.util.Locale;

/** Real percentages only: missing values have an empty track, stale values are muted. */
final class PercentRing extends View {
 final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);final String label;final int tint;final boolean small;
 double target=Double.NaN;float drawn;boolean fresh;ValueAnimator animator;
 PercentRing(Context c,String label,int color,boolean small){super(c);this.label=label;this.tint=color;this.small=small;setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_YES);}
 float dp(float n){return n*getResources().getDisplayMetrics().density;}
 void value(double next,boolean fresh){if(Double.isInfinite(next)||next<0||next>100)next=Double.NaN;this.fresh=fresh;boolean changed=Double.compare(next,target)!=0;target=next;setContentDescription(label+"，"+CardMetrics.percent(next)+(fresh?"":"，上次数据"));if(changed){if(animator!=null)animator.cancel();if(HyperStyle.motion()&&!Double.isNaN(next)){animator=ValueAnimator.ofFloat(drawn,(float)next);animator.setDuration(260);animator.addUpdateListener(a->{drawn=(float)a.getAnimatedValue();invalidate();});animator.start();}else drawn=Double.isNaN(next)?0:(float)next;}invalidate();}
 @Override protected void onDraw(Canvas c){super.onDraw(c);float cx=getWidth()/2f,cy=small?getHeight()/2f:dp(47),r=Math.min(getWidth()/2f-dp(small?5:13),dp(small?25:35));paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(dp(small?5:7));paint.setStrokeCap(Paint.Cap.ROUND);paint.setColor(HyperStyle.soft(getContext()));c.drawCircle(cx,cy,r,paint);if(!Double.isNaN(target)&&drawn>0){paint.setColor(fresh?tint:HyperStyle.muted(getContext()));c.drawArc(cx-r,cy-r,cx+r,cy+r,-90,Math.min(360,drawn*3.6f),false,paint);}paint.setStyle(Paint.Style.FILL);paint.setTextAlign(Paint.Align.CENTER);paint.setTypeface(Typeface.create("sans-serif-medium",0));paint.setTextSize(dp(small?13:20));paint.setColor(HyperStyle.ink(getContext()));Paint.FontMetrics fm=paint.getFontMetrics();c.drawText(CardMetrics.percent(target),cx,cy-(fm.ascent+fm.descent)/2,paint);if(!small){paint.setTypeface(Typeface.DEFAULT);paint.setTextSize(dp(13));paint.setColor(HyperStyle.muted(getContext()));c.drawText(label,cx,cy+r+dp(24),paint);}}
 @Override protected void onDetachedFromWindow(){if(animator!=null)animator.cancel();super.onDetachedFromWindow();}
}
