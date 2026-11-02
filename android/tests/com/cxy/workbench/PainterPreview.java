package com.cxy.workbench;
import org.json.*;
import java.awt.*;
import java.awt.geom.*;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Preview adapter for the exact production drawing geometry. Not an Android screenshot. */
public final class PainterPreview implements CardPainter.Surface {
 final Graphics2D g;
 PainterPreview(BufferedImage image,float scale){g=image.createGraphics();g.scale(scale,scale);g.setRenderingHint(RenderingHints.KEY_ANTIALIASING,RenderingHints.VALUE_ANTIALIAS_ON);g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING,RenderingHints.VALUE_TEXT_ANTIALIAS_ON);g.setRenderingHint(RenderingHints.KEY_FRACTIONALMETRICS,RenderingHints.VALUE_FRACTIONALMETRICS_ON);g.setClip(new RoundRectangle2D.Float(0,0,image.getWidth()/scale,image.getHeight()/scale,44,44));}
 void color(int c){g.setColor(new Color(c,true));}
 public void rect(float x,float y,float w,float h,float r,int c){color(c);g.fill(new RoundRectangle2D.Float(x,y,Math.max(0,w),Math.max(0,h),r*2,r*2));}
 public void line(float a,float b,float c,float d,float width,int color){color(color);g.setStroke(new BasicStroke(width,BasicStroke.CAP_ROUND,BasicStroke.JOIN_ROUND));g.draw(new Line2D.Float(a,b,c,d));}
 public void circle(float x,float y,float r,int c){color(c);g.fill(new Ellipse2D.Float(x-r,y-r,r*2,r*2));}
 public void glow(float x,float y,float r,int c){Paint old=g.getPaint();g.setPaint(new RadialGradientPaint(new Point2D.Float(x,y),r,new float[]{0,1},new Color[]{new Color(c,true),new Color(c&0x00ffffff,true)}));g.fill(new Ellipse2D.Float(x-r,y-r,r*2,r*2));g.setPaint(old);}
 public void arc(float x,float y,float r,float stroke,float start,float sweep,int c){color(c);g.setStroke(new BasicStroke(stroke,BasicStroke.CAP_BUTT,BasicStroke.JOIN_ROUND));g.draw(new Arc2D.Float(x-r,y-r,r*2,r*2,-start,-sweep,Arc2D.OPEN));}
 Font font(float size,boolean bold){return new Font("SansSerif",bold?Font.BOLD:Font.PLAIN,12).deriveFont(size);}
 public void text(String s,float x,float y,float size,int c,boolean bold){color(c);g.setFont(font(size,bold));g.drawString(s==null?"—":s,x,y);}
 public float measure(String s,float size,boolean bold){return (float)font(size,bold).getStringBounds(s==null?"—":s,g.getFontRenderContext()).getWidth();}
 static void device(Path out,JSONObject data,String kind,String name,long now,boolean dark,int width,int height)throws Exception{BufferedImage image=new BufferedImage(width,height,BufferedImage.TYPE_INT_ARGB);PainterPreview p=new PainterPreview(image,width/360f);CardPainter.device(p,data,kind,now,height/(width/360f),dark);p.g.dispose();ImageIO.write(image,"png",out.resolve(name+".png").toFile());}
 static void action(Path out,JSONObject data,String mode,String name,boolean dark,float h)throws Exception{BufferedImage image=new BufferedImage(720,(int)(h*2),BufferedImage.TYPE_INT_ARGB);PainterPreview p=new PainterPreview(image,2);ActionPainter.draw(p,data,0,mode,0,"",h,dark);p.g.dispose();ImageIO.write(image,"png",out.resolve(name+".png").toFile());}
 public static void main(String[] args)throws Exception{Path out=Paths.get(args[0]);Files.createDirectories(out);JSONObject data=new JSONObject(new String(Files.readAllBytes(Paths.get(args[1])),StandardCharsets.UTF_8)),actions=new JSONObject(new String(Files.readAllBytes(Paths.get(args[2])),StandardCharsets.UTF_8));long now=Long.parseLong(args[3]);for(String id:new String[]{"mac","winpc","linux","phone","gateway","overview"}){device(out,data,id,id+"-light",now,false,720,340);device(out,data,id,id+"-dark",now,true,720,340);device(out,null,id,id+"-missing",now,false,720,340);}action(out,actions,"ring","action-ring-light",false,470);action(out,actions,"list","action-list-light",false,470);action(out,actions,"ring","action-ring-dark",true,470);action(out,null,"ring","action-missing",false,470);System.out.println("same-drawing-code previews: "+out.toAbsolutePath());}
}
