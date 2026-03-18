// Shared testbench utilities package.
// Provides standardized logging, checking, and result reporting.

package tb_pkg;

    // Severity levels for messages
    typedef enum {
        MSG_INFO,
        MSG_WARNING,
        MSG_ERROR,
        MSG_FATAL
    } msg_severity_e;

    // Test result tracking
    int total_tests  = 0;
    int passed_tests = 0;
    int failed_tests = 0;

    // Log a message with severity and timestamp
    function automatic void log_msg(
        input msg_severity_e severity,
        input string         source,
        input string         message
    );
        string sev_str;
        case (severity)
            MSG_INFO:    sev_str = "INFO";
            MSG_WARNING: sev_str = "WARNING";
            MSG_ERROR:   sev_str = "ERROR";
            MSG_FATAL:   sev_str = "FATAL";
        endcase
        $display("[%0t] [%s] [%s] %s", $time, sev_str, source, message);
    endfunction

    // Check a condition and report pass/fail
    function automatic void check(
        input bit    condition,
        input string test_name,
        input string fail_message = ""
    );
        total_tests++;
        if (condition) begin
            passed_tests++;
            log_msg(MSG_INFO, test_name, "PASSED");
        end else begin
            failed_tests++;
            if (fail_message != "")
                log_msg(MSG_ERROR, test_name, {"FAILED: ", fail_message});
            else
                log_msg(MSG_ERROR, test_name, "FAILED");
        end
    endfunction

    // Check that two values are equal
    function automatic void check_equal(
        input longint unsigned actual,
        input longint unsigned expected,
        input string           test_name
    );
        if (actual == expected) begin
            check(1, test_name);
        end else begin
            check(0, test_name,
                  $sformatf("expected=%0d, actual=%0d", expected, actual));
        end
    endfunction

    // Print the final test summary — machine-parseable pass/fail
    function automatic void print_summary(input string suite_name);
        $display("");
        $display("==========================================================");
        $display("  Test Suite: %s", suite_name);
        $display("  Total: %0d  |  Passed: %0d  |  Failed: %0d",
                 total_tests, passed_tests, failed_tests);
        $display("----------------------------------------------------------");
        if (failed_tests == 0)
            $display("  ** TEST PASSED **");
        else
            $display("  ** TEST FAILED **");
        $display("==========================================================");
        $display("");
    endfunction

    // Reset counters (call at start of each test suite)
    function automatic void reset_counters();
        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;
    endfunction

endpackage
