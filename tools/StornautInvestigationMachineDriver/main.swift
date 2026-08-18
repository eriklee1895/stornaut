import Darwin
import StornautInvestigationMachine

@main
struct StornautInvestigationMachineDriverCommand {
    static func main() async {
        let status = await InvestigationMachineDriverEntryPoint.run()
        exit(status)
    }
}
