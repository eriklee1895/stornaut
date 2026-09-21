import Darwin
#if DEBUG
import StornautInvestigationMachineGateCoordinatorSupport
#endif
@main
struct StornautInvestigationMachineGateCoordinatorCommand {
    static func main() async {
        #if DEBUG
        exit(await InvestigationMachineGateCoordinatorSupport.run())
        #else
        exit(78)
        #endif
    }
}
