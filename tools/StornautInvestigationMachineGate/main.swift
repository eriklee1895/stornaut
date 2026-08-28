import Darwin
import StornautInvestigationMachineGateSupport

@main
struct StornautInvestigationMachineGateCommand {
    static func main() {
        exit(InvestigationMachineGateSupport.run())
    }
}
