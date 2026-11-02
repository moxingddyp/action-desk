// Native offline layout QA. Does not start any collector or modify preferences.
import AppKit
import SwiftUI
import WidgetKit
@main enum WorkbenchPreview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        guard CommandLine.arguments.count==2 || CommandLine.arguments.count==3 else {fatalError("Pass output directory")}
        let directory=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let prefsBefore=try Data(contentsOf:DeskStore.preferences)
        let devicePrefsBefore=try? Data(contentsOf:DeviceDisplayPrefs.url)
        let sourceBefore=try Data(contentsOf:DeskProjection.root.appendingPathComponent("PROJECT.md"))
        let suite="CXYWorkbenchAppearanceQA."+UUID().uuidString
        let defaults=UserDefaults(suiteName:suite)!
        defer {defaults.removePersistentDomain(forName:suite)}
        let preferences=WorkbenchAppearance(defaults:defaults)
        precondition(!preferences.dockVisible && preferences.menuVisible)
        var applied=0;preferences.apply={applied+=1}
        for pair in [(true,true),(true,false),(false,false),(false,true)] {
            preferences.dockVisible=pair.0;preferences.menuVisible=pair.1
            let loaded=WorkbenchAppearance(defaults:defaults)
            precondition(loaded.dockVisible==pair.0 && loaded.menuVisible==pair.1)
        }
        precondition(applied==8)
        print("PASS: independent appearance toggles persist all four combinations and trigger immediate application")
        try render(WorkbenchSettings(appearance:WorkbenchAppearance(),refreshWidgets:{}).frame(width:800,height:650),to:directory.appendingPathComponent("settings-page.png"))
        if CommandLine.arguments.last == "--settings-only" {
            let actionPrefsAfter=try Data(contentsOf:DeskStore.preferences)
            precondition(prefsBefore == actionPrefsAfter)
            precondition(devicePrefsBefore == (try? Data(contentsOf:DeviceDisplayPrefs.url)))
            print("PASS: settings preview rendered; action/device display preferences unchanged; no collectors started")
            return
        }
        let monitor=DeviceMonitor()
        if let data=TelemetryStore.read(){monitor.samples=data.devices;monitor.phoneSample=data.phone}
        try render(WorkbenchActionPage().frame(width:1140,height:780),to:directory.appendingPathComponent("action-page.png"))
        try render(DeviceDashboard(monitor:monitor).frame(width:1140,height:780),to:directory.appendingPathComponent("devices-page.png"))
        try render(DeviceDashboard(monitor:monitor,selection:"phone").frame(width:1140,height:780),to:directory.appendingPathComponent("phone-no-hardware-page.png"))
        var phone=monitor.phoneSample ?? DeviceSample(id:"phone",host:"offline-preview")
        phone.hardwareSampleAvailable=true;phone.hardwareFresh=true;phone.receivedAt = .now
        phone.batteryPercent=68;phone.batteryCharging=false;phone.onACPower=false
        phone.memoryUsed=7_500_000_000;phone.memoryTotal=12_000_000_000
        phone.disks=[DeviceDisk(name:"内部存储（离屏布局样例）",total:512_000_000_000,used:234_000_000_000)]
        phone.networkType="wifi";phone.networkObservedAt = .now;monitor.phoneSample=phone
        try render(DeviceDashboard(monitor:monitor,selection:"phone").frame(width:1140,height:940),to:directory.appendingPathComponent("phone-hardware-fixture-page.png"))
        let prefsAfter=try Data(contentsOf:DeskStore.preferences)
        let devicePrefsAfter=try? Data(contentsOf:DeviceDisplayPrefs.url)
        let sourceAfter=try Data(contentsOf:DeskProjection.root.appendingPathComponent("PROJECT.md"))
        precondition(prefsBefore == prefsAfter)
        precondition(devicePrefsBefore == devicePrefsAfter)
        precondition(sourceBefore == sourceAfter)
        print("PASS: 5 native page previews; collectors never started; formal source and both display preferences unchanged")
    }
    @MainActor static func render<V:View>(_ view:V,to url:URL)throws {
        // ImageRenderer omits AppKit-backed ScrollView contents. A real offscreen
        // NSHostingView lays out the same native page without starting the App.
        let host=NSHostingView(rootView:view.environment(\.colorScheme,.light))
        let size=host.fittingSize
        let window=NSWindow(contentRect:NSRect(origin:NSPoint(x:-10000,y:-10000),size:size),styleMask:.borderless,backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.contentView=host
        host.frame=NSRect(origin:.zero,size:size)
        window.orderFront(nil)
        RunLoop.main.run(until:Date().addingTimeInterval(0.25))
        host.layoutSubtreeIfNeeded()
        guard let bitmap=host.bitmapImageRepForCachingDisplay(in:host.bounds) else {throw CocoaError(.fileWriteUnknown)}
        host.cacheDisplay(in:host.bounds,to:bitmap)
        guard let png=bitmap.representation(using:.png,properties:[:]) else {throw CocoaError(.fileWriteUnknown)}
        try png.write(to:url);window.close()
    }
}
