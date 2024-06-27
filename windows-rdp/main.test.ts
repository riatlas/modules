import { describe, expect, it } from "bun:test";
import {
  TerraformState,
  runTerraformApply,
  runTerraformInit,
  testRequiredVariables,
} from "../test";

type TestVariables = Readonly<{
  agent_id: string;
  resource_id: string;
  admin_username?: string;
  admin_password?: string;
}>;

function findWindowsRpdScript(state: TerraformState): string | null {
  for (const resource of state.resources) {
    const isRdpScriptResource =
      resource.type === "coder_script" && resource.name === "windows-rdp";

    if (!isRdpScriptResource) {
      continue;
    }

    for (const instance of resource.instances) {
      if (instance.attributes.display_name === "windows-rdp") {
        return instance.attributes.script;
      }
    }
  }

  return null;
}

/**
 * @todo It would be nice if we had a way to verify that the Devolutions root
 * HTML file is modified to include the import for the patched Coder script,
 * but the current test setup doesn't really make that viable
 */
describe("Web RDP", async () => {
  await runTerraformInit(import.meta.dir);
  testRequiredVariables<TestVariables>(import.meta.dir, {
    agent_id: "foo",
    resource_id: "bar",
  });

  it("Has the PowerShell script install Devolutions Gateway", async () => {
    const state = await runTerraformApply<TestVariables>(import.meta.dir, {
      agent_id: "foo",
      resource_id: "bar",
    });

    const lines = findWindowsRpdScript(state)
      .split("\n")
      .filter(Boolean)
      .map((line) => line.trimStart());

    expect(lines).toEqual(
      expect.arrayContaining<string>([
        '$moduleName = "DevolutionsGateway"',
        // Devolutions does versioning in the format year.minor.patch
        expect.stringMatching(/^\$moduleVersion = "\d{4}\.\d+\.\d+"$/),
        "Install-Module -Name $moduleName -RequiredVersion $moduleVersion -Force",
      ]),
    );
  });

  it("Injects Terraform's username and password into the JS patch file", async () => {
    /**
     * Using a regex as a quick-and-dirty way to get at the username and
     * password values.
     *
     * Tried going through the trouble of extracting out the form entries
     * variable from the main output, converting it from Prettier/JS-based JSON
     * text to universal JSON text, and exposing it as a parsed JSON value. That
     * got to be a bit too much, though.
     *
     * Regex is a little bit more verbose and pedantic than normal. Want to
     * have some basic safety nets for validating the structure of the form
     * entries variable after the JS file has had values injected. Really do
     * not want the wildcard classes to overshoot and grab too much content,
     * even if they're all set to lazy mode.
     *
     * Written and tested via Regex101
     * @see {@link https://regex101.com/r/UMgQpv/2}
     */
    const formEntryValuesRe =
      /^const formFieldEntries = \{$.*?^\s+username: \{$.*?^\s*?querySelector.*?,$.*?^\s*value: "(?<username>.+?)",$.*?password: \{$.*?^\s+querySelector: .*?,$.*?^\s*value: "(?<password>.+?)",$.*?^};$/ms;

    // Test that things work with the default username/password
    const defaultState = await runTerraformApply<TestVariables>(
      import.meta.dir,
      {
        agent_id: "foo",
        resource_id: "bar",
      },
    );

    const defaultRdpScript = findWindowsRpdScript(defaultState);
    expect(defaultRdpScript).toBeString();

    const { username: defaultUsername, password: defaultPassword } =
      formEntryValuesRe.exec(defaultRdpScript)?.groups ?? {};

    expect(defaultUsername).toBe("Administrator");
    expect(defaultPassword).toBe("coderRDP!");

    // Test that custom usernames/passwords are also forwarded correctly
    const customAdminUsername = "crouton";
    const customAdminPassword = "VeryVeryVeryVeryVerySecurePassword97!";
    const customizedState = await runTerraformApply<TestVariables>(
      import.meta.dir,
      {
        agent_id: "foo",
        resource_id: "bar",
        admin_username: customAdminUsername,
        admin_password: customAdminPassword,
      },
    );

    const customRdpScript = findWindowsRpdScript(customizedState);
    expect(customRdpScript).toBeString();

    const { username: customUsername, password: customPassword } =
      formEntryValuesRe.exec(customRdpScript)?.groups ?? {};

    expect(customUsername).toBe(customAdminUsername);
    expect(customPassword).toBe(customAdminPassword);
  });
});
