"""
Test Coverage Analysis Tool
Analyzes test coverage and generates comprehensive reports
"""

import os
import sys
import ast
import json
import argparse
from pathlib import Path
from typing import Dict, List, Set, Tuple
from collections import defaultdict
import importlib.util


class TestCoverageAnalyzer:
    """Analyzes test coverage for the MS5.0 system"""
    
    def __init__(self, source_dir: str = "backend/app", test_dir: str = "."):
        self.source_dir = Path(source_dir)
        self.test_dir = Path(test_dir)
        self.source_files = {}
        self.test_files = {}
        self.coverage_data = {}
        
    def analyze_coverage(self) -> Dict:
        """Analyze test coverage and return comprehensive report"""
        print("🔍 Analyzing test coverage...")
        
        # Discover source files
        self._discover_source_files()
        
        # Discover test files
        self._discover_test_files()
        
        # Analyze coverage
        self._analyze_file_coverage()
        
        # Generate report
        report = self._generate_coverage_report()
        
        return report
    
    def _discover_source_files(self):
        """Discover all Python source files"""
        print("📁 Discovering source files...")
        
        for py_file in self.source_dir.rglob("*.py"):
            if py_file.name != "__init__.py":
                relative_path = py_file.relative_to(self.source_dir.parent)
                self.source_files[str(relative_path)] = {
                    "path": str(py_file),
                    "relative_path": str(relative_path),
                    "lines": self._count_lines(py_file),
                    "functions": self._extract_functions(py_file),
                    "classes": self._extract_classes(py_file)
                }
        
        print(f"   Found {len(self.source_files)} source files")
    
    def _discover_test_files(self):
        """Discover all test files"""
        print("🧪 Discovering test files...")
        
        test_patterns = ["test_*.py", "*_test.py", "test_*_test.py"]
        
        for pattern in test_patterns:
            for test_file in self.test_dir.rglob(pattern):
                if test_file.is_file():
                    relative_path = str(test_file.relative_to(self.test_dir))
                    self.test_files[relative_path] = {
                        "path": str(test_file),
                        "relative_path": relative_path,
                        "lines": self._count_lines(test_file),
                        "test_functions": self._extract_test_functions(test_file),
                        "test_classes": self._extract_test_classes(test_file)
                    }
        
        print(f"   Found {len(self.test_files)} test files")
    
    def _analyze_file_coverage(self):
        """Analyze coverage for each source file"""
        print("📊 Analyzing file coverage...")
        
        for source_path, source_info in self.source_files.items():
            # Find corresponding test files
            test_files = self._find_test_files_for_source(source_path)
            
            # Analyze coverage
            coverage_info = {
                "source_file": source_path,
                "test_files": test_files,
                "functions_tested": self._analyze_function_coverage(source_path, test_files),
                "classes_tested": self._analyze_class_coverage(source_path, test_files),
                "coverage_percentage": 0.0,
                "status": "unknown"
            }
            
            # Calculate coverage percentage
            total_functions = len(source_info["functions"])
            total_classes = len(source_info["classes"])
            tested_functions = len(coverage_info["functions_tested"])
            tested_classes = len(coverage_info["classes_tested"])
            
            if total_functions + total_classes > 0:
                coverage_info["coverage_percentage"] = (
                    (tested_functions + tested_classes) / (total_functions + total_classes)
                ) * 100
            
            # Determine status
            if coverage_info["coverage_percentage"] >= 95:
                coverage_info["status"] = "excellent"
            elif coverage_info["coverage_percentage"] >= 80:
                coverage_info["status"] = "good"
            elif coverage_info["coverage_percentage"] >= 60:
                coverage_info["status"] = "fair"
            elif coverage_info["coverage_percentage"] >= 40:
                coverage_info["status"] = "poor"
            else:
                coverage_info["status"] = "critical"
            
            self.coverage_data[source_path] = coverage_info
    
    def _find_test_files_for_source(self, source_path: str) -> List[str]:
        """Find test files that correspond to a source file"""
        source_name = Path(source_path).stem
        
        # Look for test files that might test this source file
        test_files = []
        
        for test_path, test_info in self.test_files.items():
            test_name = Path(test_path).stem.lower()
            
            # Check if test file name suggests it tests this source file
            if (source_name.lower() in test_name or 
                test_name.replace("test_", "").replace("_test", "") == source_name.lower() or
                any(keyword in test_name for keyword in ["comprehensive", "integration", "e2e"])):
                test_files.append(test_path)
        
        return test_files
    
    def _analyze_function_coverage(self, source_path: str, test_files: List[str]) -> Set[str]:
        """Analyze which functions are tested"""
        source_info = self.source_files[source_path]
        tested_functions = set()
        
        for test_file in test_files:
            test_info = self.test_files[test_file]
            
            # Look for test functions that might test source functions
            for test_func in test_info["test_functions"]:
                test_func_name = test_func.lower()
                
                for source_func in source_info["functions"]:
                    source_func_name = source_func.lower()
                    
                    # Check if test function tests source function
                    if (source_func_name in test_func_name or
                        test_func_name.replace("test_", "").replace("_test", "") == source_func_name):
                        tested_functions.add(source_func)
        
        return tested_functions
    
    def _analyze_class_coverage(self, source_path: str, test_files: List[str]) -> Set[str]:
        """Analyze which classes are tested"""
        source_info = self.source_files[source_path]
        tested_classes = set()
        
        for test_file in test_files:
            test_info = self.test_files[test_file]
            
            # Look for test classes that might test source classes
            for test_class in test_info["test_classes"]:
                test_class_name = test_class.lower()
                
                for source_class in source_info["classes"]:
                    source_class_name = source_class.lower()
                    
                    # Check if test class tests source class
                    if (source_class_name in test_class_name or
                        test_class_name.replace("test", "") == source_class_name):
                        tested_classes.add(source_class)
        
        return tested_classes
    
    def _generate_coverage_report(self) -> Dict:
        """Generate comprehensive coverage report"""
        print("📋 Generating coverage report...")
        
        # Calculate overall statistics
        total_files = len(self.source_files)
        total_functions = sum(len(info["functions"]) for info in self.source_files.values())
        total_classes = sum(len(info["classes"]) for info in self.source_files.values())
        
        total_tested_functions = sum(len(data["functions_tested"]) for data in self.coverage_data.values())
        total_tested_classes = sum(len(data["classes_tested"]) for data in self.coverage_data.values())
        
        overall_coverage = 0.0
        if total_functions + total_classes > 0:
            overall_coverage = ((total_tested_functions + total_tested_classes) / 
                              (total_functions + total_classes)) * 100
        
        # Categorize files by coverage status
        status_counts = defaultdict(int)
        for data in self.coverage_data.values():
            status_counts[data["status"]] += 1
        
        # Generate detailed report
        report = {
            "summary": {
                "total_source_files": total_files,
                "total_functions": total_functions,
                "total_classes": total_classes,
                "total_tested_functions": total_tested_functions,
                "total_tested_classes": total_tested_classes,
                "overall_coverage_percentage": round(overall_coverage, 2),
                "target_coverage": 95.0,
                "coverage_gap": max(0, 95.0 - overall_coverage)
            },
            "status_breakdown": dict(status_counts),
            "file_details": self.coverage_data,
            "recommendations": self._generate_recommendations(),
            "test_quality_metrics": self._analyze_test_quality()
        }
        
        return report
    
    def _generate_recommendations(self) -> List[str]:
        """Generate recommendations for improving test coverage"""
        recommendations = []
        
        # Analyze coverage data
        uncovered_files = [path for path, data in self.coverage_data.items() 
                          if data["status"] in ["poor", "critical"]]
        
        if uncovered_files:
            recommendations.append(f"Priority: Add tests for {len(uncovered_files)} files with poor coverage")
            
            # List top priority files
            priority_files = sorted(uncovered_files, 
                                  key=lambda x: self.coverage_data[x]["coverage_percentage"])[:5]
            for file_path in priority_files:
                coverage_pct = self.coverage_data[file_path]["coverage_percentage"]
                recommendations.append(f"  - {file_path} ({coverage_pct:.1f}% coverage)")
        
        # Check for missing test types
        if len(self.test_files) < 10:
            recommendations.append("Consider adding more comprehensive test suites")
        
        # Check test distribution
        unit_tests = [f for f in self.test_files.keys() if "test_services" in f or "unit" in f.lower()]
        integration_tests = [f for f in self.test_files.keys() if "test_integration" in f or "integration" in f.lower()]
        e2e_tests = [f for f in self.test_files.keys() if "test_e2e" in f or "e2e" in f.lower()]
        
        if len(unit_tests) == 0:
            recommendations.append("Add unit tests for individual functions and classes")
        if len(integration_tests) == 0:
            recommendations.append("Add integration tests for API endpoints and services")
        if len(e2e_tests) == 0:
            recommendations.append("Add end-to-end tests for complete user workflows")
        
        return recommendations
    
    def _analyze_test_quality(self) -> Dict:
        """Analyze test quality metrics"""
        quality_metrics = {
            "total_test_files": len(self.test_files),
            "total_test_functions": sum(len(info["test_functions"]) for info in self.test_files.values()),
            "total_test_classes": sum(len(info["test_classes"]) for info in self.test_files.values()),
            "average_test_file_size": 0,
            "test_types": {
                "unit_tests": 0,
                "integration_tests": 0,
                "e2e_tests": 0,
                "performance_tests": 0,
                "security_tests": 0
            }
        }
        
        if self.test_files:
            quality_metrics["average_test_file_size"] = sum(info["lines"] for info in self.test_files.values()) / len(self.test_files)
        
        # Categorize test files
        for test_path in self.test_files.keys():
            test_path_lower = test_path.lower()
            
            if "test_services" in test_path_lower or "unit" in test_path_lower:
                quality_metrics["test_types"]["unit_tests"] += 1
            elif "test_integration" in test_path_lower or "integration" in test_path_lower:
                quality_metrics["test_types"]["integration_tests"] += 1
            elif "test_e2e" in test_path_lower or "e2e" in test_path_lower:
                quality_metrics["test_types"]["e2e_tests"] += 1
            elif "test_performance" in test_path_lower or "performance" in test_path_lower:
                quality_metrics["test_types"]["performance_tests"] += 1
            elif "test_security" in test_path_lower or "security" in test_path_lower:
                quality_metrics["test_types"]["security_tests"] += 1
        
        return quality_metrics
    
    def _count_lines(self, file_path: Path) -> int:
        """Count lines in a file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return len(f.readlines())
        except Exception:
            return 0
    
    def _extract_functions(self, file_path: Path) -> List[str]:
        """Extract function names from a Python file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            tree = ast.parse(content)
            functions = []
            
            for node in ast.walk(tree):
                if isinstance(node, ast.FunctionDef):
                    functions.append(node.name)
            
            return functions
        except Exception:
            return []
    
    def _extract_classes(self, file_path: Path) -> List[str]:
        """Extract class names from a Python file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            tree = ast.parse(content)
            classes = []
            
            for node in ast.walk(tree):
                if isinstance(node, ast.ClassDef):
                    classes.append(node.name)
            
            return classes
        except Exception:
            return []
    
    def _extract_test_functions(self, file_path: Path) -> List[str]:
        """Extract test function names from a test file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            tree = ast.parse(content)
            test_functions = []
            
            for node in ast.walk(tree):
                if isinstance(node, ast.FunctionDef) and node.name.startswith('test_'):
                    test_functions.append(node.name)
            
            return test_functions
        except Exception:
            return []
    
    def _extract_test_classes(self, file_path: Path) -> List[str]:
        """Extract test class names from a test file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            tree = ast.parse(content)
            test_classes = []
            
            for node in ast.walk(tree):
                if isinstance(node, ast.ClassDef) and ('Test' in node.name or 'test' in node.name.lower()):
                    test_classes.append(node.name)
            
            return test_classes
        except Exception:
            return []
    
    def print_report(self, report: Dict):
        """Print formatted coverage report"""
        print("\n" + "="*80)
        print("🧪 MS5.0 TEST COVERAGE ANALYSIS REPORT")
        print("="*80)
        
        # Summary
        summary = report["summary"]
        print(f"\n📊 SUMMARY:")
        print(f"   Total Source Files: {summary['total_source_files']}")
        print(f"   Total Functions: {summary['total_functions']}")
        print(f"   Total Classes: {summary['total_classes']}")
        print(f"   Tested Functions: {summary['total_tested_functions']}")
        print(f"   Tested Classes: {summary['total_tested_classes']}")
        print(f"   Overall Coverage: {summary['overall_coverage_percentage']:.1f}%")
        print(f"   Target Coverage: {summary['target_coverage']:.1f}%")
        print(f"   Coverage Gap: {summary['coverage_gap']:.1f}%")
        
        # Status breakdown
        print(f"\n📈 COVERAGE STATUS BREAKDOWN:")
        status_icons = {
            "excellent": "🟢",
            "good": "🟡",
            "fair": "🟠",
            "poor": "🔴",
            "critical": "⚫"
        }
        
        for status, count in report["status_breakdown"].items():
            icon = status_icons.get(status, "⚪")
            print(f"   {icon} {status.title()}: {count} files")
        
        # Test quality metrics
        quality = report["test_quality_metrics"]
        print(f"\n🧪 TEST QUALITY METRICS:")
        print(f"   Total Test Files: {quality['total_test_files']}")
        print(f"   Total Test Functions: {quality['total_test_functions']}")
        print(f"   Total Test Classes: {quality['total_test_classes']}")
        print(f"   Average Test File Size: {quality['average_test_file_size']:.1f} lines")
        
        print(f"\n📋 TEST TYPE DISTRIBUTION:")
        for test_type, count in quality["test_types"].items():
            if count > 0:
                print(f"   {test_type.replace('_', ' ').title()}: {count} files")
        
        # Recommendations
        print(f"\n💡 RECOMMENDATIONS:")
        for i, recommendation in enumerate(report["recommendations"], 1):
            print(f"   {i}. {recommendation}")
        
        # Top files needing attention
        print(f"\n🎯 FILES NEEDING ATTENTION:")
        critical_files = [path for path, data in report["file_details"].items() 
                         if data["status"] in ["poor", "critical"]]
        
        if critical_files:
            sorted_files = sorted(critical_files, 
                                key=lambda x: report["file_details"][x]["coverage_percentage"])
            
            for file_path in sorted_files[:10]:  # Show top 10
                coverage_data = report["file_details"][file_path]
                status_icon = status_icons.get(coverage_data["status"], "⚪")
                print(f"   {status_icon} {file_path}: {coverage_data['coverage_percentage']:.1f}% coverage")
        else:
            print("   🎉 All files have good coverage!")
        
        print("\n" + "="*80)
    
    def save_report(self, report: Dict, output_file: str = "test_coverage_report.json"):
        """Save coverage report to JSON file"""
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"📄 Coverage report saved to: {output_file}")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description="MS5.0 Test Coverage Analysis Tool")
    parser.add_argument("--source-dir", default="backend/app", 
                       help="Source code directory (default: backend/app)")
    parser.add_argument("--test-dir", default=".", 
                       help="Test files directory (default: current directory)")
    parser.add_argument("--output", default="test_coverage_report.json",
                       help="Output JSON report file (default: test_coverage_report.json)")
    parser.add_argument("--quiet", action="store_true",
                       help="Suppress progress output")
    
    args = parser.parse_args()
    
    if not args.quiet:
        print("🚀 MS5.0 Test Coverage Analysis Tool")
        print(f"📁 Source directory: {args.source_dir}")
        print(f"🧪 Test directory: {args.test_dir}")
    
    # Create analyzer
    analyzer = TestCoverageAnalyzer(args.source_dir, args.test_dir)
    
    # Analyze coverage
    report = analyzer.analyze_coverage()
    
    # Print report
    if not args.quiet:
        analyzer.print_report(report)
    
    # Save report
    analyzer.save_report(report, args.output)
    
    # Return exit code based on coverage
    coverage = report["summary"]["overall_coverage_percentage"]
    if coverage >= 95:
        return 0  # Success
    elif coverage >= 80:
        return 1  # Warning
    else:
        return 2  # Error


if __name__ == "__main__":
    sys.exit(main())
