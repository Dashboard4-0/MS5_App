#!/usr/bin/env python3
"""
Quality Gates Evaluation Script
Starship-grade quality validation for production deployments
"""

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Any, Optional
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class QualityGateEvaluator:
    """Evaluates code quality gates with starship-grade precision."""
    
    def __init__(self, config_path: Optional[str] = None):
        """Initialize the quality gate evaluator."""
        self.config = self._load_config(config_path)
        self.results = {
            'overall_status': 'unknown',
            'gates_evaluated': 0,
            'gates_passed': 0,
            'gates_failed': 0,
            'gate_results': [],
            'summary': {},
            'recommendations': []
        }
    
    def _load_config(self, config_path: Optional[str]) -> Dict[str, Any]:
        """Load quality gate configuration."""
        default_config = {
            'quality_gates': [
                {
                    'name': 'unit-test-coverage',
                    'threshold': 85,
                    'metric': 'coverage_percentage',
                    'action': 'block',
                    'severity': 'critical'
                },
                {
                    'name': 'critical-vulnerabilities',
                    'threshold': 0,
                    'metric': 'critical_vulnerabilities',
                    'action': 'block',
                    'severity': 'critical'
                },
                {
                    'name': 'high-vulnerabilities',
                    'threshold': 2,
                    'metric': 'high_vulnerabilities',
                    'action': 'warn',
                    'severity': 'high'
                },
                {
                    'name': 'license-compliance',
                    'threshold': 100,
                    'metric': 'license_compliance_percentage',
                    'action': 'block',
                    'severity': 'high'
                }
            ]
        }
        
        if config_path and Path(config_path).exists():
            try:
                with open(config_path, 'r') as f:
                    return json.load(f)
            except Exception as e:
                logger.warning(f"Failed to load config from {config_path}: {e}")
        
        return default_config
    
    def evaluate_coverage(self, coverage_file: str) -> Dict[str, Any]:
        """Evaluate test coverage from XML report."""
        try:
            tree = ET.parse(coverage_file)
            root = tree.getroot()
            
            # Extract coverage percentage
            line_rate = float(root.attrib.get('line-rate', 0))
            coverage_percentage = int(line_rate * 100)
            
            # Extract detailed metrics
            lines_covered = int(root.attrib.get('lines-covered', 0))
            lines_valid = int(root.attrib.get('lines-valid', 0))
            
            return {
                'coverage_percentage': coverage_percentage,
                'lines_covered': lines_covered,
                'lines_valid': lines_valid,
                'branch_coverage': self._extract_branch_coverage(root)
            }
        except Exception as e:
            logger.error(f"Failed to parse coverage report: {e}")
            return {'coverage_percentage': 0}
    
    def _extract_branch_coverage(self, root: ET.Element) -> float:
        """Extract branch coverage from XML."""
        try:
            branch_rate = float(root.attrib.get('branch-rate', 0))
            return int(branch_rate * 100)
        except:
            return 0
    
    def evaluate_security(self, bandit_file: str, safety_file: str, audit_file: str) -> Dict[str, Any]:
        """Evaluate security vulnerabilities."""
        security_results = {
            'critical_vulnerabilities': 0,
            'high_vulnerabilities': 0,
            'medium_vulnerabilities': 0,
            'low_vulnerabilities': 0,
            'total_vulnerabilities': 0,
            'details': []
        }
        
        # Parse Bandit results
        if Path(bandit_file).exists():
            try:
                with open(bandit_file, 'r') as f:
                    bandit_data = json.load(f)
                
                for result in bandit_data.get('results', []):
                    severity = result.get('issue_severity', 'LOW').upper()
                    if severity == 'HIGH':
                        security_results['high_vulnerabilities'] += 1
                    elif severity == 'MEDIUM':
                        security_results['medium_vulnerabilities'] += 1
                    else:
                        security_results['low_vulnerabilities'] += 1
                    
                    security_results['details'].append({
                        'tool': 'bandit',
                        'severity': severity,
                        'issue': result.get('test_name', 'Unknown'),
                        'file': result.get('filename', 'Unknown')
                    })
            except Exception as e:
                logger.error(f"Failed to parse Bandit report: {e}")
        
        # Parse Safety results
        if Path(safety_file).exists():
            try:
                with open(safety_file, 'r') as f:
                    safety_data = json.load(f)
                
                for vuln in safety_data:
                    # Safety vulnerabilities are typically high severity
                    security_results['high_vulnerabilities'] += 1
                    security_results['details'].append({
                        'tool': 'safety',
                        'severity': 'HIGH',
                        'issue': vuln.get('advisory', 'Unknown'),
                        'package': vuln.get('package_name', 'Unknown')
                    })
            except Exception as e:
                logger.error(f"Failed to parse Safety report: {e}")
        
        # Parse pip-audit results
        if Path(audit_file).exists():
            try:
                with open(audit_file, 'r') as f:
                    audit_data = json.load(f)
                
                for vuln in audit_data.get('vulnerabilities', []):
                    # Classify pip-audit vulnerabilities
                    severity = 'HIGH'  # Default to high for security vulnerabilities
                    security_results['high_vulnerabilities'] += 1
                    security_results['details'].append({
                        'tool': 'pip-audit',
                        'severity': severity,
                        'issue': vuln.get('id', 'Unknown'),
                        'package': vuln.get('package', 'Unknown')
                    })
            except Exception as e:
                logger.error(f"Failed to parse pip-audit report: {e}")
        
        # Calculate totals
        security_results['total_vulnerabilities'] = (
            security_results['critical_vulnerabilities'] +
            security_results['high_vulnerabilities'] +
            security_results['medium_vulnerabilities'] +
            security_results['low_vulnerabilities']
        )
        
        return security_results
    
    def evaluate_license_compliance(self) -> Dict[str, Any]:
        """Evaluate license compliance (placeholder implementation)."""
        # In a real implementation, this would check all dependencies
        # against an approved license list
        return {
            'license_compliance_percentage': 100,
            'non_compliant_packages': [],
            'total_packages': 0
        }
    
    def evaluate_gate(self, gate_config: Dict[str, Any], metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Evaluate a single quality gate."""
        gate_name = gate_config['name']
        metric_name = gate_config['metric']
        threshold = gate_config['threshold']
        action = gate_config['action']
        severity = gate_config['severity']
        
        # Get the metric value
        current_value = metrics.get(metric_name, 0)
        
        # Determine if gate passes
        if metric_name in ['coverage_percentage', 'license_compliance_percentage']:
            # Higher is better
            passed = current_value >= threshold
        else:
            # Lower is better (vulnerabilities, etc.)
            passed = current_value <= threshold
        
        result = {
            'name': gate_name,
            'metric': metric_name,
            'threshold': threshold,
            'current_value': current_value,
            'passed': passed,
            'action': action,
            'severity': severity,
            'blocking': action == 'block'
        }
        
        # Add recommendations
        if not passed:
            result['recommendation'] = self._get_recommendation(gate_name, current_value, threshold)
        
        return result
    
    def _get_recommendation(self, gate_name: str, current_value: Any, threshold: Any) -> str:
        """Get recommendation for failed gate."""
        recommendations = {
            'unit-test-coverage': f"Increase test coverage from {current_value}% to at least {threshold}%. Add unit tests for uncovered code paths.",
            'critical-vulnerabilities': f"Fix {current_value} critical security vulnerabilities before deployment.",
            'high-vulnerabilities': f"Address {current_value} high-severity vulnerabilities (threshold: {threshold}).",
            'license-compliance': f"Ensure all dependencies have approved licenses. Current compliance: {current_value}%"
        }
        
        return recommendations.get(gate_name, f"Improve {gate_name} metric from {current_value} to meet threshold of {threshold}")
    
    def evaluate_all_gates(self, coverage_file: str, bandit_file: str, 
                          safety_file: str, audit_file: str) -> Dict[str, Any]:
        """Evaluate all quality gates."""
        logger.info("Starting quality gate evaluation...")
        
        # Collect metrics
        coverage_metrics = self.evaluate_coverage(coverage_file)
        security_metrics = self.evaluate_security(bandit_file, safety_file, audit_file)
        license_metrics = self.evaluate_license_compliance()
        
        # Combine all metrics
        all_metrics = {**coverage_metrics, **security_metrics, **license_metrics}
        
        # Evaluate each gate
        blocking_failures = 0
        warning_failures = 0
        
        for gate_config in self.config['quality_gates']:
            gate_result = self.evaluate_gate(gate_config, all_metrics)
            self.results['gate_results'].append(gate_result)
            self.results['gates_evaluated'] += 1
            
            if gate_result['passed']:
                self.results['gates_passed'] += 1
            else:
                self.results['gates_failed'] += 1
                if gate_result['blocking']:
                    blocking_failures += 1
                else:
                    warning_failures += 1
                
                if 'recommendation' in gate_result:
                    self.results['recommendations'].append(gate_result['recommendation'])
        
        # Determine overall status
        if blocking_failures > 0:
            self.results['overall_status'] = 'failed'
        elif warning_failures > 0:
            self.results['overall_status'] = 'passed_with_warnings'
        else:
            self.results['overall_status'] = 'passed'
        
        # Add summary
        self.results['summary'] = {
            'coverage_percentage': coverage_metrics.get('coverage_percentage', 0),
            'total_vulnerabilities': security_metrics.get('total_vulnerabilities', 0),
            'critical_vulnerabilities': security_metrics.get('critical_vulnerabilities', 0),
            'high_vulnerabilities': security_metrics.get('high_vulnerabilities', 0),
            'license_compliance': license_metrics.get('license_compliance_percentage', 0),
            'blocking_failures': blocking_failures,
            'warning_failures': warning_failures
        }
        
        logger.info(f"Quality gate evaluation completed. Status: {self.results['overall_status']}")
        return self.results


def main():
    """Main function."""
    parser = argparse.ArgumentParser(description='Evaluate quality gates for MS5.0 deployment')
    parser.add_argument('--coverage-report', required=True, help='Path to coverage XML report')
    parser.add_argument('--security-report', required=True, help='Path to Bandit JSON report')
    parser.add_argument('--safety-report', required=True, help='Path to Safety JSON report')
    parser.add_argument('--audit-report', required=True, help='Path to pip-audit JSON report')
    parser.add_argument('--threshold', type=int, default=85, help='Coverage threshold percentage')
    parser.add_argument('--config', help='Path to quality gates configuration file')
    parser.add_argument('--output', required=True, help='Output file for results')
    
    args = parser.parse_args()
    
    try:
        evaluator = QualityGateEvaluator(args.config)
        results = evaluator.evaluate_all_gates(
            args.coverage_report,
            args.security_report,
            args.safety_report,
            args.audit_report
        )
        
        # Write results to file
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        
        # Print summary
        print(f"Quality Gate Evaluation Results:")
        print(f"Overall Status: {results['overall_status'].upper()}")
        print(f"Gates Passed: {results['gates_passed']}/{results['gates_evaluated']}")
        print(f"Coverage: {results['summary']['coverage_percentage']}%")
        print(f"Critical Vulnerabilities: {results['summary']['critical_vulnerabilities']}")
        print(f"High Vulnerabilities: {results['summary']['high_vulnerabilities']}")
        
        if results['recommendations']:
            print("\nRecommendations:")
            for i, rec in enumerate(results['recommendations'], 1):
                print(f"{i}. {rec}")
        
        # Exit with appropriate code
        if results['overall_status'] == 'failed':
            sys.exit(1)
        elif results['overall_status'] == 'passed_with_warnings':
            sys.exit(2)
        else:
            sys.exit(0)
            
    except Exception as e:
        logger.error(f"Quality gate evaluation failed: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
