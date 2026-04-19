from __future__ import annotations

import unittest

from django.test.runner import DiscoverRunner


class EmojiTextTestResult(unittest.TextTestResult):
    """A unittest result that prints ✅/❌ for each test.

    - ✅: success
    - ❌: failure, error, skip, xfail/unexpected-success
    """

    def __init__(self, stream, descriptions, verbosity):
        super().__init__(stream, descriptions, verbosity)
        #disabling the built-in dot/"... ok" output
        self.showAll = False
        self.dots = False

    def _write(self, prefix: str, test: unittest.case.TestCase, extra: str = "") -> None:
        desc = self.getDescription(test)
        if extra:
            self.stream.writeln(f"{prefix} {desc} ({extra})")
        else:
            self.stream.writeln(f"{prefix} {desc}")
        self.stream.flush()

    def addSuccess(self, test):
        unittest.TestResult.addSuccess(self, test)
        self._write("✅", test)

    def addFailure(self, test, err):
        super().addFailure(test, err)
        self._write("❌", test)

    def addError(self, test, err):
        super().addError(test, err)
        self._write("❌❌", test, extra="error")

    def addSkip(self, test, reason):
        super().addSkip(test, reason)
        self._write("⚠️", test, extra=f"skipped: {reason}")

    def addExpectedFailure(self, test, err):
        super().addExpectedFailure(test, err)
        self._write("❌", test, extra="expected failure")

    def addUnexpectedSuccess(self, test):
        super().addUnexpectedSuccess(test)
        self._write("❌", test, extra="unexpected success")


class EmojiTextTestRunner(unittest.TextTestRunner):
    resultclass = EmojiTextTestResult


class EmojiDiscoverRunner(DiscoverRunner):
    """Django test runner that uses EmojiTextTestRunner."""

    test_runner = EmojiTextTestRunner
