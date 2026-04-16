//
//  TheWidgetLiveActivity.swift
//  TheWidget
//
//  Created by Charm Xu on 2026/4/16.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TheWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TheWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TheWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TheWidgetAttributes {
    fileprivate static var preview: TheWidgetAttributes {
        TheWidgetAttributes(name: "World")
    }
}

extension TheWidgetAttributes.ContentState {
    fileprivate static var smiley: TheWidgetAttributes.ContentState {
        TheWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TheWidgetAttributes.ContentState {
         TheWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TheWidgetAttributes.preview) {
   TheWidgetLiveActivity()
} contentStates: {
    TheWidgetAttributes.ContentState.smiley
    TheWidgetAttributes.ContentState.starEyes
}
