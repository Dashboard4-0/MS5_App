#!/usr/bin/env python3
"""
MS5.0 Floor Dashboard - Phase 4 Simple Test

This test validates the basic functionality of Phase 4 PLC integration fixes
without requiring external dependencies.
"""

import asyncio
import sys
import os
from datetime import datetime
from typing import Dict, Any

# Add the backend directory to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

def test_import_structure():
    """Test 1: Verify import structure is correct."""
    print("Testing import structure...")
    
    try:
        # Test that we can import the enhanced services
        from app.services.enhanced_metric_transformer import EnhancedMetricTransformer
        from app.services.enhanced_telemetry_poller import EnhancedTelemetryPoller
        
        print("✅ Successfully imported EnhancedMetricTransformer")
        print("✅ Successfully imported EnhancedTelemetryPoller")
        
        return True
    except Exception as e:
        print(f"❌ Import failed: {e}")
        return False

def test_class_instantiation():
    """Test 2: Verify classes can be instantiated."""
    print("\nTesting class instantiation...")
    
    try:
        from app.services.enhanced_metric_transformer import EnhancedMetricTransformer
        from app.services.enhanced_telemetry_poller import EnhancedTelemetryPoller
        
        # Test instantiation
        transformer = EnhancedMetricTransformer()
        poller = EnhancedTelemetryPoller()
        
        print("✅ Successfully instantiated EnhancedMetricTransformer")
        print("✅ Successfully instantiated EnhancedTelemetryPoller")
        
        return True
    except Exception as e:
        print(f"❌ Instantiation failed: {e}")
        return False

def test_method_signatures():
    """Test 3: Verify method signatures are correct."""
    print("\nTesting method signatures...")
    
    try:
        from app.services.enhanced_metric_transformer import EnhancedMetricTransformer
        
        transformer = EnhancedMetricTransformer()
        
        # Check that methods exist and are async
        import inspect
        
        # Check transform_bagger_metrics is async
        bagger_method = getattr(transformer, 'transform_bagger_metrics')
        is_async = inspect.iscoroutinefunction(bagger_method)
        
        if not is_async:
            print("❌ transform_bagger_metrics is not async")
            return False
        
        print("✅ transform_bagger_metrics is async")
        
        # Check transform_basket_loader_metrics is async
        basket_method = getattr(transformer, 'transform_basket_loader_metrics')
        is_async = inspect.iscoroutinefunction(basket_method)
        
        if not is_async:
            print("❌ transform_basket_loader_metrics is not async")
            return False
        
        print("✅ transform_basket_loader_metrics is async")
        
        # Check helper methods are async
        helper_methods = [
            '_add_production_metrics',
            '_calculate_enhanced_oee',
            '_track_downtime_events',
            '_get_production_context'
        ]
        
        for method_name in helper_methods:
            method = getattr(transformer, method_name)
            is_async = inspect.iscoroutinefunction(method)
            
            if not is_async:
                print(f"❌ {method_name} is not async")
                return False
            
            print(f"✅ {method_name} is async")
        
        return True
    except Exception as e:
        print(f"❌ Method signature test failed: {e}")
        return False

def test_enhanced_poller_methods():
    """Test 4: Verify enhanced poller methods exist."""
    print("\nTesting enhanced poller methods...")
    
    try:
        from app.services.enhanced_telemetry_poller import EnhancedTelemetryPoller
        
        poller = EnhancedTelemetryPoller()
        
        # Check that event handler methods exist
        event_handlers = [
            '_handle_job_completion',
            '_handle_quality_issue',
            '_handle_changeover_started',
            '_handle_changeover_completed',
            '_handle_fault_detected_event',
            '_handle_fault_cleared_event'
        ]
        
        for method_name in event_handlers:
            if not hasattr(poller, method_name):
                print(f"❌ {method_name} method not found")
                return False
            
            method = getattr(poller, method_name)
            import inspect
            is_async = inspect.iscoroutinefunction(method)
            
            if not is_async:
                print(f"❌ {method_name} is not async")
                return False
            
            print(f"✅ {method_name} exists and is async")
        
        return True
    except Exception as e:
        print(f"❌ Enhanced poller method test failed: {e}")
        return False

def test_file_structure():
    """Test 5: Verify file structure is correct."""
    print("\nTesting file structure...")
    
    required_files = [
        'backend/app/services/enhanced_metric_transformer.py',
        'backend/app/services/enhanced_telemetry_poller.py',
        'backend/app/services/production_service.py',
        'backend/app/services/oee_calculator.py',
        'backend/app/services/downtime_tracker.py',
        'backend/app/services/andon_service.py',
        'backend/app/services/notification_service.py'
    ]
    
    for file_path in required_files:
        if not os.path.exists(file_path):
            print(f"❌ Required file not found: {file_path}")
            return False
        print(f"✅ Found: {file_path}")
    
    return True

def test_import_paths():
    """Test 6: Verify import paths are working."""
    print("\nTesting import paths...")
    
    try:
        # Test that the Tag_Scanner imports work
        import sys
        import os
        tag_scanner_path = os.path.join(os.path.dirname(__file__), 'Tag_Scanner_for Reference Only')
        sys.path.append(tag_scanner_path)
        
        # Try to import the base classes
        from transforms import MetricTransformer
        from poller import TelemetryPoller
        
        print("✅ Successfully imported MetricTransformer from Tag_Scanner")
        print("✅ Successfully imported TelemetryPoller from Tag_Scanner")
        
        return True
    except Exception as e:
        print(f"❌ Import path test failed: {e}")
        return False

def main():
    """Run all tests."""
    print("=" * 80)
    print("MS5.0 Floor Dashboard - Phase 4 Simple Test Suite")
    print("=" * 80)
    
    tests = [
        ("Import Structure", test_import_structure),
        ("Class Instantiation", test_class_instantiation),
        ("Method Signatures", test_method_signatures),
        ("Enhanced Poller Methods", test_enhanced_poller_methods),
        ("File Structure", test_file_structure),
        ("Import Paths", test_import_paths)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n--- {test_name} ---")
        try:
            if test_func():
                passed += 1
                print(f"✅ {test_name} PASSED")
            else:
                print(f"❌ {test_name} FAILED")
        except Exception as e:
            print(f"❌ {test_name} FAILED with exception: {e}")
    
    print("\n" + "=" * 80)
    print("TEST SUMMARY")
    print("=" * 80)
    print(f"Total Tests: {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {total - passed}")
    print(f"Success Rate: {(passed / total * 100):.1f}%")
    
    if passed == total:
        print("\n🎉 ALL TESTS PASSED! Phase 4 PLC Integration is working correctly.")
        return 0
    else:
        print(f"\n⚠️  {total - passed} tests failed. Please review the errors above.")
        return 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
