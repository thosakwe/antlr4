/*
 * Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
package org.antlr.v4.test.runtime.dart;

import org.antlr.v4.test.runtime.ErrorQueue;
import org.antlr.v4.test.runtime.RuntimeTestSupport;
import org.antlr.v4.test.runtime.StreamVacuum;
import org.stringtemplate.v4.ST;

import java.io.File;
import java.nio.file.FileSystems;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;

import static junit.framework.TestCase.assertTrue;
import static org.antlr.v4.test.runtime.BaseRuntimeTest.antlrOnString;
import static org.antlr.v4.test.runtime.BaseRuntimeTest.writeFile;

public class BaseDartTest implements RuntimeTestSupport {
	public File overall_tmpdir = null;
	public File tmpdir = null;
	String stderrDuringParse = null;
	StringBuilder antlrToolErrors;

	@Override
	public void testSetUp() throws Exception {
		// new output dir for each test
		String prop = System.getProperty("antlr-dart-test-dir");
		if (prop != null && prop.length() > 0) {
			overall_tmpdir = new File(prop);
		} else {
			String threadName = Thread.currentThread().getName();
			overall_tmpdir = new File(System.getProperty("java.io.tmpdir"),
					getClass().getSimpleName() + "-" + threadName + "-" + System.currentTimeMillis());
			//overall_tmpdir = new File(".antlr_dart");
		}


		eraseTempDir();

		antlrToolErrors = new StringBuilder();
	}

	@Override
	public void testTearDown() throws Exception {

	}

	@Override
	public void eraseTempDir() {
		if (overall_tmpdir.exists() && !overall_tmpdir.delete())
			System.out.println("Could not delete overall temp dir: " + overall_tmpdir.getAbsolutePath());

		tmpdir = new File(overall_tmpdir, "parser");

		if (tmpdir.exists() && !tmpdir.delete())
			System.out.println("Could not delete temp dir: " + tmpdir.getAbsolutePath());
	}

	@Override
	public String getTmpDir() {
		return tmpdir.getPath();
	}

	@Override
	public String getStdout() {
		return null;
	}

	@Override
	public String getParseErrors() {
		return stderrDuringParse;
	}

	@Override
	public String getANTLRToolErrors() {
		return antlrToolErrors.length() == 0 ? null : antlrToolErrors.toString();
	}

	private static String locateDart() {
		ArrayList<String> paths = new ArrayList<>();

		// DART_SDK should have priority if set
		String dartSdkRoot = System.getenv("DART_SDK");
		if (dartSdkRoot != null) {
			paths.add(dartSdkRoot + File.separatorChar + "bin");
		}

		String pathEnv = System.getenv("PATH");
		if (pathEnv != null) {
			paths.addAll(Arrays.asList(pathEnv.split(File.pathSeparator)));
		}

		// OS specific default locations of binary dist as last resort
		paths.add("/usr/lib/dart");
		paths.add("c:\\Program Files\\Dart\\dart-sdk");

		// HOMEBREW_INSTALL/opt/dart/libexec
		String homebrew = System.getenv("HOMEBREW_INSTALL");

		if (homebrew != null) {
			paths.add(homebrew + File.separatorChar + "opt" + File.separatorChar + "dart" + File.separatorChar + "libexec");
		}

		for (String path : paths) {
			File candidate = new File(new File(path), "dart");
			if (candidate.exists()) {
				return candidate.getPath();
			}
			candidate = new File(new File(path), "dart.exe");
			if (candidate.exists()) {
				return candidate.getPath();
			}
		}
		return null;
	}

	public String execModule(String fileName) {
		// We MUST find the .packages file from target/classes/Dart
		Path currentPath = FileSystems.getDefault().getPath(".").toAbsolutePath();
		Path packagesPath = Paths.get(currentPath.toString(), "targets", "classes", "Dart", ".packages");

		String dartExecutable = locateDart();
		String modulePath = new File(overall_tmpdir, fileName).getAbsolutePath();
		String inputPath = new File(overall_tmpdir, "input").getAbsolutePath();
		try {
			ProcessBuilder builder = new ProcessBuilder(dartExecutable, "--packages=" + packagesPath.toString(), modulePath, inputPath);
			builder.directory(overall_tmpdir);
			Process process = builder.start();
			StreamVacuum stdoutVacuum = new StreamVacuum(process.getInputStream());
			StreamVacuum stderrVacuum = new StreamVacuum(process.getErrorStream());
			stdoutVacuum.start();
			stderrVacuum.start();
			process.waitFor();
			stdoutVacuum.join();
			stderrVacuum.join();
			String output = stdoutVacuum.toString();
			if (output.length() == 0) {
				output = null;
			}
			if (stderrVacuum.toString().length() > 0) {
				this.stderrDuringParse = stderrVacuum.toString();
			}
			return output;
		} catch (Exception e) {
			System.err.println("can't exec recognizer");
			e.printStackTrace(System.err);
		}
		return null;
	}

	@Override
	public String execLexer(String grammarFileName, String grammarStr, String lexerName, String input, boolean showDFA) {
		boolean success = rawGenerateAndBuildRecognizer(grammarFileName,
				grammarStr, null, lexerName, "-no-listener");
		assertTrue(success);
		writeFile(overall_tmpdir.toString(), "input", input);
		writeLexerTestFile(lexerName, showDFA);
		return execModule("test.dart");
	}

	protected void writeLexerTestFile(String lexerName, boolean showDFA) {
		ST outputFileST = new ST(
				"import 'package:antlr/antlr.dart';"
						+ "import 'lexer_dart.dart';\n"
						+ "main(List\\<String> args) async {\n"
						+ "  var contents = await new File(args[0]).readAsString();\n"
						+ "  var input = new ANTLRInputStream(contents);\n"
						+ "  var lexer = new <lexerName>(input);\n"
						+ "  var stream = new CommonTokenStream(lexer);\n"
						+ "  for (var token in stream.allTokens()) {\n"
						+ "    print(t.getText());\n"
						+ "  }\n"
						+ "}\n"
		);
		// TODO: ShowDFA for Dart lexer tests
		outputFileST.add("lexerName", lexerName);
		writeFile(overall_tmpdir.toString(), "test.dart", outputFileST.render());
	}


	/**
	 * Return true if all is well
	 */
	protected boolean rawGenerateAndBuildRecognizer(String grammarFileName,
													String grammarStr, String parserName, String lexerName,
													String... extraOptions) {
		return rawGenerateAndBuildRecognizer(grammarFileName, grammarStr,
				parserName, lexerName, false, extraOptions);
	}

	/**
	 * Return true if all is well
	 */
	protected boolean rawGenerateAndBuildRecognizer(String grammarFileName,
													String grammarStr, String parserName, String lexerName,
													boolean defaultListener, String... extraOptions) {
		ErrorQueue equeue = antlrOnString(getTmpDir(), "Dart", grammarFileName, grammarStr,
				defaultListener, extraOptions);
		return equeue.errors.isEmpty();
	}


	@Override
	public String execParser(String grammarFileName, String grammarStr, String parserName, String lexerName, String listenerName, String visitorName, String startRuleName, String input, boolean showDiagnosticErrors) {
		boolean success = rawGenerateAndBuildRecognizer(grammarFileName,
				grammarStr, parserName, lexerName, "-visitor");
		assertTrue(success);
		writeFile(overall_tmpdir.toString(), "input", input);
		rawBuildRecognizerTestFile(parserName, lexerName, listenerName,
				visitorName, startRuleName, showDiagnosticErrors);
		return execRecognizer();
	}

	protected void rawBuildRecognizerTestFile(String parserName,
											  String lexerName, String listenerName, String visitorName,
											  String parserStartRuleName, boolean debug) {
		this.stderrDuringParse = null;
		if (parserName == null) {
			writeLexerTestFile(lexerName, false);
		} else {
			writeParserTestFile(parserName, lexerName, listenerName,
					visitorName, parserStartRuleName, debug);
		}
	}

	protected void writeParserTestFile(String parserName, String lexerName,
									   String listenerName, String visitorName,
									   String parserStartRuleName, boolean debug) {
		ST outputFileST = new ST(
				"import 'dart:io';"
						+ "import 'package:antlr/antlr.dart';"
						+ "import 'package:file/local.dart';"
						+ "import 'lexer_dart.dart';\n"
						+ "import 'parser_dart.dart';\n"
						+ "main(List\\<String> args) async {\n"
						+ "  var contents = await new File(args[0]).readAsString();\n"
						+ "  var input = new ANTLRInputStream(contents);\n"
						+ "  var lexer = new <lexerName>(input);\n"
						+ "  var stream = new CommonTokenStream(lexer);\n"
						+ "  <createParser>\n"
						+ "  p.buildParseTrees = true;\n"
						+ "  var tree = p.<parserStartRuleName>();\n"
						+ "  ParseTreeWalker.DEFAULT.walk(new TreeShapeListener(), tree);\n"
						+ "}\n\n"
						+ "class TreeShapeListener implements ParseTreeListener {\n"

						+ "@override\n" +
						"		void enterEveryRule(ParserRuleContext ctx) {\n" +
						"			for (int i = 0; i \\< ctx.childCount; i++) {\n" +
						"				ParseTree parent = ctx.getChild(i).parent;\n" +
						"				if (!(parent is RuleNode) || (parent as RuleNode).ruleContext != ctx) {\n" +
						"					throw new StateError(\"Invalid parse tree shape detected.\");\n" +
						"				}\n" +
						"			}\n" +
						"		}\n"
						+ "}\n"
		);

		ST createParserST = new ST(
				"	var p = new <parserName>(stream);\n");
		if (debug) {
			createParserST = new ST(
					"	var p = new <parserName>(stream);\n"
							+ "	p.addErrorListener(new DiagnosticErrorListener(true));\n");
		}
		outputFileST.add("createParser", createParserST);
		outputFileST.add("parserName", parserName);
		outputFileST.add("lexerName", lexerName);
		outputFileST.add("listenerName", listenerName);
		outputFileST.add("visitorName", visitorName);
		outputFileST.add("parserStartRuleName", parserStartRuleName.substring(0, 1).toUpperCase() + parserStartRuleName.substring(1));
		writeFile(overall_tmpdir.toString(), "test.dart", outputFileST.render());
	}

	public String execRecognizer() {
		return execModule("test.dart");
	}

	public static void groupSetUp() {
	}

	public static void groupTearDown() {
	}
}
