// Editable code-native vector mark. Raster outputs are generated from this view.
import AppKit
import SwiftUI
struct WorkbenchIcon:View {
    let blue=Color(red:0.035,green:0.36,blue:1)
    var body:some View {
        ZStack {
            RoundedRectangle(cornerRadius:190,style:.continuous)
                .fill(LinearGradient(colors:[Color(red:0.025,green:0.50,blue:1),Color(red:0.20,green:0.26,blue:0.98),Color(red:0.43,green:0.16,blue:0.91)],startPoint:.topLeading,endPoint:.bottomTrailing))
                .frame(width:832,height:832).shadow(color:Color.blue.opacity(0.14),radius:16,y:10)
            VStack(spacing:42) {
                HStack(spacing:42) {
                    tile(.white) {
                        VStack(alignment:.leading,spacing:24) {
                            ForEach(0..<3) {n in HStack(spacing:16) {
                                Image(systemName:"checkmark").font(.system(size:24,weight:.black)).foregroundStyle(blue)
                                RoundedRectangle(cornerRadius:8).fill(blue.opacity(n==2 ? 0.55:0.90)).frame(width:n==1 ? 92:115,height:16)
                            }}
                        }
                    }
                    tile(Color(red:0.07,green:0.86,blue:0.85)) {
                        VStack(spacing:9) {
                            RoundedRectangle(cornerRadius:14).stroke(.white,lineWidth:13).frame(width:137,height:95)
                            Capsule().fill(.white).frame(width:82,height:12)
                        }
                    }
                }
                HStack(spacing:42) {
                    tile(Color(red:0.64,green:0.43,blue:1)) {
                        HStack(alignment:.bottom,spacing:17) {
                            Capsule().fill(.white.opacity(0.80)).frame(width:26,height:57)
                            Capsule().fill(.white).frame(width:26,height:118)
                            Capsule().fill(.white.opacity(0.90)).frame(width:26,height:87)
                        }.frame(height:120,alignment:.bottom)
                    }
                    tile(Color(red:0.34,green:0.70,blue:1)) {
                        ZStack {
                            Path {p in p.move(to:CGPoint(x:42,y:45));p.addLine(to:CGPoint(x:130,y:45));p.addLine(to:CGPoint(x:86,y:124));p.closeSubpath()}.stroke(.white.opacity(0.92),style:StrokeStyle(lineWidth:11,lineJoin:.round))
                            ForEach([CGPoint(x:42,y:45),CGPoint(x:130,y:45),CGPoint(x:86,y:124)],id:\.x) {position in
                                Circle().fill(.white).frame(width:36,height:36).position(position)
                            }
                        }.frame(width:172,height:165)
                    }
                }
            }.frame(width:538,height:538)
        }.frame(width:1024,height:1024)
    }
    func tile<C:View>(_ color:Color,@ViewBuilder content:()->C)->some View {
        content().frame(width:248,height:248).background(color,in:RoundedRectangle(cornerRadius:57,style:.continuous))
    }
}
@main enum WorkbenchIconGenerator {
    @MainActor static func main()throws {
        _=NSApplication.shared
        guard CommandLine.arguments.count==2 else {fatalError("Pass output .iconset directory")}
        let directory=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        for points in [16,32,128,256,512] {
            for scale in [1,2] {
                let size=CGFloat(points*scale)
                let icon=WorkbenchIcon().scaleEffect(size/1024).frame(width:size,height:size)
                let renderer=ImageRenderer(content:icon);renderer.scale=1
                guard let data=renderer.nsImage?.tiffRepresentation,let bitmap=NSBitmapImageRep(data:data),let png=bitmap.representation(using:.png,properties:[:]) else {throw CocoaError(.fileWriteUnknown)}
                let name="icon_\(points)x\(points)"+(scale==2 ? "@2x":"")+".png"
                try png.write(to:directory.appendingPathComponent(name))
            }
        }
        print("Generated editable vector-derived color workbench icon sizes16–1024")
    }
}
