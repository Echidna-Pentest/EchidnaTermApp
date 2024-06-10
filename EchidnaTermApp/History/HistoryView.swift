//
//  HistoryView.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 3/29/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import CoreData
import MapKit

struct Pair: View {
    var first: LocalizedStringKey
    var second: String
    
    init (_ first: LocalizedStringKey, _ second: String) {
        self.first = first
        self.second = second
    }
    
    var body: some View {
        HStack {
            Text (first)
            Spacer ()
            Text (second)
                .foregroundColor(.secondary)
        }
    }
}

struct MakeMap: View {
    @State var region: MKCoordinateRegion
    @State var loc: HistoryLocation
    var body: some View {
        return Map (coordinateRegion: $region, annotationItems: [loc]) { place in
            MapPin(coordinate: place.coordinate)
        }
    }
}
struct HistoryDetail: View {
    var historyRecord: HistoryRecord
    
    func render (_ sloc: HistoryLocation?) -> some View {
        #if test
        guard let loc = sloc else {
            return AnyView (Text ("Location unavailable"))
        }
        #else
        let loc = HistoryLocation (latitude: 51.507222, longitude: -0.1275)
        #endif
        let long = loc.longitude.formatted(.number)
        let lat = loc.latitude.formatted(.number)
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))

        return AnyView (VStack {
            Pair ("Longitude", "\(long)")
            Pair ("Latitude", "\(lat)")
            MakeMap (region: region, loc: loc)
                .frame(minWidth: 300, minHeight: 300)

        }.padding ([.leading]))
    }
    
    var body: some View {
        Form {
            Pair ("Alias", historyRecord.alias)
            Pair ("Username", historyRecord.username ?? "")
            Pair ("Address", historyRecord.hostname ?? "")
            Pair ("Date", dateMediumFormatter.string(from: historyRecord.date ?? Date ()))
            Pair ("Time", timeFormatter.string(from: historyRecord.date ?? Date ()))
            switch historyRecord.typedEvent {
            case .none:
                Pair ("Typed", "Error")
            case .connected(at: let loc):
                VStack (alignment: .leading) {
                    Text ("Connected")
                    render (loc)
                }
            case .disconnected(at: let loc):
                VStack (alignment: .leading) {
                    Text ("Disconnected")
                    render (loc)
                }
            case .moved(newLocation: let loc):
                VStack (alignment: .leading) {
                    Text ("Moved")
                    render (loc)
                }
            }
        }
    
    }
}

struct HistoryView: View {
    @SectionedFetchRequest(
      sectionIdentifier: \.renderedDate,
      sortDescriptors: [SortDescriptor (\HistoryRecord.date, order: .reverse)],
      animation: .default)
    var history: SectionedFetchResults<String, HistoryRecord>
    @Environment(\.managedObjectContext) var moc
    
    var body: some View {
        List {
            ForEach (history){ section in
                Section (header: Text (section.id)) {
                    ForEach (section) { historyRecord in
                        NavigationLink (destination: HistoryDetail (historyRecord: historyRecord)) {
                            HStack {
                                getHostImage(forKind: historyRecord.hostkind ?? "")
                                    .font (.system(size: 28))

                                VStack (alignment: .leading, spacing: 4) {
                                    HStack (alignment: .firstTextBaseline){
                                        Text (historyRecord.alias)
                                        Text ("(\(historyRecord.hostname ?? "Deleted"))")
                                            .foregroundColor(.secondary)
                                            .font (.footnote)
                                    }
                                    Text ("\(timeFormatter.string (from: (historyRecord.date ?? Date())))")
                                        .font (.subheadline)
                                }
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem (placement: .navigationBarTrailing) {
                Button ("Clear") {
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "HistoryRecord")
                    let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

                    do {
                        try moc.execute(batchDeleteRequest)
                    } catch {
                        print("Error deleting all data for HistoryRecord:", error)
                    }
                    try? moc.save ()
                    
                    /// Poor man's refresh: change the predicate to force a refresh, this is the only hack I could find that works
                    let old = history.nsPredicate
                    history.nsPredicate = NSPredicate (value: true)
                    history .nsPredicate = old
                }
            }
        }
        .listStyle(DefaultListStyle())
        .navigationTitle(Text("History"))
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
