//
//  TheWidgetBundle.swift
//  TheWidget
//
//  Created by Charm Xu on 2026/4/16.
//

import WidgetKit
import SwiftUI

@main
struct TheWidgetBundle: WidgetBundle {
    var body: some Widget {
        TheWidget()
        TheWidgetControl()
        TheWidgetLiveActivity()
    }
}
