import Darwin
import StornautInvestigationMachineDriverSupport

@main
struct StornautInvestigationMachineDriverCommand {
    static func main() async {
        let status = await InvestigationMachineDriverSupport.run()
        exit(status)
    }
}
