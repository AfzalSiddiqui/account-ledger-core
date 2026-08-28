import Foundation

@main
struct AccountLedgerCore {
    static func main() {
        print("Account Ledger Core — Event Stream Replay")
        print("")

        let events = Event.eventStream()

        var processor = EventProcessor()
        processor.process(events: events)
    }
}
