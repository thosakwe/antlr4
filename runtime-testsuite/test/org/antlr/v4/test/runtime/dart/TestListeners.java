/*
 * Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

package org.antlr.v4.test.runtime.dart;

import org.antlr.v4.test.runtime.BaseRuntimeTest;
import org.antlr.v4.test.runtime.RuntimeTestDescriptor;
import org.antlr.v4.test.runtime.descriptors.ListenersDescriptors;
import org.antlr.v4.test.runtime.dart.BaseDartTest;
import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;

@RunWith(Parameterized.class)
public class TestListeners extends BaseRuntimeTest {
	public TestListeners(RuntimeTestDescriptor descriptor) {
		super(descriptor,new BaseDartTest());
	}

	@BeforeClass
	public static void groupSetUp() throws Exception { BaseDartTest.groupSetUp(); }

	@AfterClass
	public static void groupTearDown() throws Exception { BaseDartTest.groupTearDown(); }

	@Parameterized.Parameters(name="{0}")
	public static RuntimeTestDescriptor[] getAllTestDescriptors() {
		return BaseRuntimeTest.getRuntimeTestDescriptors(ListenersDescriptors.class, "Dart");
	}
}
