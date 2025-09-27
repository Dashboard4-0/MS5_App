"""
Performance Monitoring and Benchmarking Tool
Monitors system performance and generates benchmarking reports
"""

import time
import psutil
import asyncio
import httpx
import json
import statistics
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
import argparse
import sys
from pathlib import Path


@dataclass
class PerformanceMetrics:
    """Performance metrics data class"""
    timestamp: datetime
    cpu_percent: float
    memory_percent: float
    memory_mb: float
    disk_io_read: int
    disk_io_write: int
    network_sent: int
    network_recv: int
    process_count: int
    load_average: List[float]


@dataclass
class APIResponseMetrics:
    """API response metrics data class"""
    endpoint: str
    method: str
    response_time_ms: float
    status_code: int
    response_size_bytes: int
    timestamp: datetime


@dataclass
class BenchmarkResult:
    """Benchmark result data class"""
    test_name: str
    total_time_seconds: float
    operations_per_second: float
    average_response_time_ms: float
    p95_response_time_ms: float
    p99_response_time_ms: float
    error_rate_percent: float
    timestamp: datetime


class PerformanceMonitor:
    """System performance monitoring"""
    
    def __init__(self):
        self.metrics_history = []
        self.api_metrics_history = []
        self.benchmark_results = []
        self.monitoring = False
    
    def start_monitoring(self, interval_seconds: int = 5):
        """Start continuous performance monitoring"""
        self.monitoring = True
        print(f"🔍 Starting performance monitoring (interval: {interval_seconds}s)")
        
        try:
            while self.monitoring:
                metrics = self.collect_system_metrics()
                self.metrics_history.append(metrics)
                
                # Keep only last 1000 metrics to prevent memory issues
                if len(self.metrics_history) > 1000:
                    self.metrics_history = self.metrics_history[-1000:]
                
                time.sleep(interval_seconds)
        except KeyboardInterrupt:
            print("\n⏹️  Performance monitoring stopped")
            self.monitoring = False
    
    def stop_monitoring(self):
        """Stop performance monitoring"""
        self.monitoring = False
    
    def collect_system_metrics(self) -> PerformanceMetrics:
        """Collect current system performance metrics"""
        # CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Memory usage
        memory = psutil.virtual_memory()
        memory_percent = memory.percent
        memory_mb = memory.used / 1024 / 1024
        
        # Disk I/O
        disk_io = psutil.disk_io_counters()
        disk_io_read = disk_io.read_bytes if disk_io else 0
        disk_io_write = disk_io.write_bytes if disk_io else 0
        
        # Network I/O
        network_io = psutil.net_io_counters()
        network_sent = network_io.bytes_sent if network_io else 0
        network_recv = network_io.bytes_recv if network_io else 0
        
        # Process count
        process_count = len(psutil.pids())
        
        # Load average (Unix-like systems only)
        try:
            load_average = list(psutil.getloadavg())
        except AttributeError:
            load_average = [0.0, 0.0, 0.0]
        
        return PerformanceMetrics(
            timestamp=datetime.now(),
            cpu_percent=cpu_percent,
            memory_percent=memory_percent,
            memory_mb=memory_mb,
            disk_io_read=disk_io_read,
            disk_io_write=disk_io_write,
            network_sent=network_sent,
            network_recv=network_recv,
            process_count=process_count,
            load_average=load_average
        )
    
    def get_performance_summary(self, duration_minutes: int = 5) -> Dict:
        """Get performance summary for the last N minutes"""
        cutoff_time = datetime.now() - timedelta(minutes=duration_minutes)
        recent_metrics = [m for m in self.metrics_history if m.timestamp >= cutoff_time]
        
        if not recent_metrics:
            return {"error": "No metrics available for the specified duration"}
        
        # Calculate statistics
        cpu_values = [m.cpu_percent for m in recent_metrics]
        memory_values = [m.memory_percent for m in recent_metrics]
        memory_mb_values = [m.memory_mb for m in recent_metrics]
        
        summary = {
            "duration_minutes": duration_minutes,
            "sample_count": len(recent_metrics),
            "cpu": {
                "average": statistics.mean(cpu_values),
                "min": min(cpu_values),
                "max": max(cpu_values),
                "p95": sorted(cpu_values)[int(0.95 * len(cpu_values))]
            },
            "memory": {
                "average_percent": statistics.mean(memory_values),
                "min_percent": min(memory_values),
                "max_percent": max(memory_values),
                "average_mb": statistics.mean(memory_mb_values),
                "max_mb": max(memory_mb_values)
            },
            "processes": {
                "average_count": statistics.mean([m.process_count for m in recent_metrics]),
                "max_count": max([m.process_count for m in recent_metrics])
            }
        }
        
        return summary


class APIPerformanceMonitor:
    """API performance monitoring"""
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.response_metrics = []
    
    async def test_endpoint_performance(self, endpoint: str, method: str = "GET", 
                                      headers: Optional[Dict] = None, 
                                      json_data: Optional[Dict] = None,
                                      num_requests: int = 10) -> List[APIResponseMetrics]:
        """Test endpoint performance with multiple requests"""
        print(f"🌐 Testing {method} {endpoint} ({num_requests} requests)")
        
        response_metrics = []
        
        async with httpx.AsyncClient(base_url=self.base_url) as client:
            for i in range(num_requests):
                start_time = time.time()
                
                try:
                    if method.upper() == "GET":
                        response = await client.get(endpoint, headers=headers)
                    elif method.upper() == "POST":
                        response = await client.post(endpoint, json=json_data, headers=headers)
                    elif method.upper() == "PUT":
                        response = await client.put(endpoint, json=json_data, headers=headers)
                    elif method.upper() == "DELETE":
                        response = await client.delete(endpoint, headers=headers)
                    else:
                        raise ValueError(f"Unsupported HTTP method: {method}")
                    
                    end_time = time.time()
                    response_time_ms = (end_time - start_time) * 1000
                    
                    metrics = APIResponseMetrics(
                        endpoint=endpoint,
                        method=method,
                        response_time_ms=response_time_ms,
                        status_code=response.status_code,
                        response_size_bytes=len(response.content),
                        timestamp=datetime.now()
                    )
                    
                    response_metrics.append(metrics)
                    
                except Exception as e:
                    print(f"❌ Request {i+1} failed: {e}")
                    
                    # Record failed request
                    metrics = APIResponseMetrics(
                        endpoint=endpoint,
                        method=method,
                        response_time_ms=0,
                        status_code=0,
                        response_size_bytes=0,
                        timestamp=datetime.now()
                    )
                    response_metrics.append(metrics)
        
        self.response_metrics.extend(response_metrics)
        return response_metrics
    
    def analyze_endpoint_performance(self, endpoint: str, method: str = "GET") -> Dict:
        """Analyze performance for a specific endpoint"""
        endpoint_metrics = [m for m in self.response_metrics 
                          if m.endpoint == endpoint and m.method == method]
        
        if not endpoint_metrics:
            return {"error": f"No metrics found for {method} {endpoint}"}
        
        response_times = [m.response_time_ms for m in endpoint_metrics]
        status_codes = [m.status_code for m in endpoint_metrics]
        response_sizes = [m.response_size_bytes for m in endpoint_metrics]
        
        # Calculate statistics
        analysis = {
            "endpoint": endpoint,
            "method": method,
            "total_requests": len(endpoint_metrics),
            "successful_requests": len([s for s in status_codes if 200 <= s < 300]),
            "error_requests": len([s for s in status_codes if s >= 400]),
            "error_rate_percent": (len([s for s in status_codes if s >= 400]) / len(status_codes)) * 100,
            "response_time": {
                "average_ms": statistics.mean(response_times),
                "min_ms": min(response_times),
                "max_ms": max(response_times),
                "p95_ms": sorted(response_times)[int(0.95 * len(response_times))],
                "p99_ms": sorted(response_times)[int(0.99 * len(response_times))]
            },
            "response_size": {
                "average_bytes": statistics.mean(response_sizes),
                "min_bytes": min(response_sizes),
                "max_bytes": max(response_sizes)
            },
            "status_codes": dict(zip(*np.unique(status_codes, return_counts=True)))
        }
        
        return analysis


class BenchmarkSuite:
    """Comprehensive benchmark suite"""
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.benchmark_results = []
    
    async def run_load_test(self, endpoint: str, method: str = "GET",
                           headers: Optional[Dict] = None,
                           json_data: Optional[Dict] = None,
                           concurrent_requests: int = 10,
                           total_requests: int = 100,
                           test_name: str = None) -> BenchmarkResult:
        """Run load test on an endpoint"""
        if test_name is None:
            test_name = f"Load test {method} {endpoint}"
        
        print(f"🚀 Running {test_name} ({total_requests} requests, {concurrent_requests} concurrent)")
        
        start_time = time.time()
        response_times = []
        errors = 0
        
        async def make_request():
            async with httpx.AsyncClient(base_url=self.base_url) as client:
                request_start = time.time()
                
                try:
                    if method.upper() == "GET":
                        response = await client.get(endpoint, headers=headers)
                    elif method.upper() == "POST":
                        response = await client.post(endpoint, json=json_data, headers=headers)
                    elif method.upper() == "PUT":
                        response = await client.put(endpoint, json=json_data, headers=headers)
                    elif method.upper() == "DELETE":
                        response = await client.delete(endpoint, headers=headers)
                    
                    request_end = time.time()
                    response_times.append((request_end - request_start) * 1000)
                    
                    if response.status_code >= 400:
                        errors += 1
                        
                except Exception:
                    errors += 1
                    response_times.append(0)
        
        # Run concurrent requests
        semaphore = asyncio.Semaphore(concurrent_requests)
        
        async def bounded_request():
            async with semaphore:
                await make_request()
        
        # Execute all requests
        tasks = [bounded_request() for _ in range(total_requests)]
        await asyncio.gather(*tasks)
        
        end_time = time.time()
        total_time = end_time - start_time
        
        # Calculate statistics
        if response_times:
            avg_response_time = statistics.mean(response_times)
            p95_response_time = sorted(response_times)[int(0.95 * len(response_times))]
            p99_response_time = sorted(response_times)[int(0.99 * len(response_times))]
        else:
            avg_response_time = p95_response_time = p99_response_time = 0
        
        ops_per_second = total_requests / total_time if total_time > 0 else 0
        error_rate = (errors / total_requests) * 100 if total_requests > 0 else 0
        
        result = BenchmarkResult(
            test_name=test_name,
            total_time_seconds=total_time,
            operations_per_second=ops_per_second,
            average_response_time_ms=avg_response_time,
            p95_response_time_ms=p95_response_time,
            p99_response_time_ms=p99_response_time,
            error_rate_percent=error_rate,
            timestamp=datetime.now()
        )
        
        self.benchmark_results.append(result)
        return result
    
    async def run_comprehensive_benchmark(self, endpoints: List[Dict], 
                                        test_config: Dict = None) -> List[BenchmarkResult]:
        """Run comprehensive benchmark on multiple endpoints"""
        if test_config is None:
            test_config = {
                "concurrent_requests": 5,
                "total_requests": 50,
                "test_name_prefix": "Comprehensive"
            }
        
        print(f"🧪 Running comprehensive benchmark suite")
        print(f"   Endpoints: {len(endpoints)}")
        print(f"   Concurrent requests: {test_config['concurrent_requests']}")
        print(f"   Total requests per endpoint: {test_config['total_requests']}")
        
        results = []
        
        for endpoint_config in endpoints:
            endpoint = endpoint_config["endpoint"]
            method = endpoint_config.get("method", "GET")
            headers = endpoint_config.get("headers")
            json_data = endpoint_config.get("json_data")
            
            test_name = f"{test_config['test_name_prefix']} {method} {endpoint}"
            
            result = await self.run_load_test(
                endpoint=endpoint,
                method=method,
                headers=headers,
                json_data=json_data,
                concurrent_requests=test_config["concurrent_requests"],
                total_requests=test_config["total_requests"],
                test_name=test_name
            )
            
            results.append(result)
        
        return results
    
    def generate_benchmark_report(self, results: List[BenchmarkResult] = None) -> Dict:
        """Generate comprehensive benchmark report"""
        if results is None:
            results = self.benchmark_results
        
        if not results:
            return {"error": "No benchmark results available"}
        
        # Calculate overall statistics
        total_tests = len(results)
        total_requests = sum(r.total_time_seconds * r.operations_per_second for r in results)
        avg_ops_per_second = statistics.mean([r.operations_per_second for r in results])
        avg_response_time = statistics.mean([r.average_response_time_ms for r in results])
        avg_error_rate = statistics.mean([r.error_rate_percent for r in results])
        
        # Find best and worst performers
        best_ops = max(results, key=lambda r: r.operations_per_second)
        worst_ops = min(results, key=lambda r: r.operations_per_second)
        fastest_response = min(results, key=lambda r: r.average_response_time_ms)
        slowest_response = max(results, key=lambda r: r.average_response_time_ms)
        
        report = {
            "summary": {
                "total_tests": total_tests,
                "total_requests_estimated": int(total_requests),
                "average_ops_per_second": avg_ops_per_second,
                "average_response_time_ms": avg_response_time,
                "average_error_rate_percent": avg_error_rate
            },
            "best_performers": {
                "highest_ops_per_second": {
                    "test_name": best_ops.test_name,
                    "ops_per_second": best_ops.operations_per_second
                },
                "fastest_response_time": {
                    "test_name": fastest_response.test_name,
                    "response_time_ms": fastest_response.average_response_time_ms
                }
            },
            "worst_performers": {
                "lowest_ops_per_second": {
                    "test_name": worst_ops.test_name,
                    "ops_per_second": worst_ops.operations_per_second
                },
                "slowest_response_time": {
                    "test_name": slowest_response.test_name,
                    "response_time_ms": slowest_response.average_response_time_ms
                }
            },
            "detailed_results": [asdict(result) for result in results]
        }
        
        return report


class PerformanceReporter:
    """Performance reporting and visualization"""
    
    def __init__(self):
        self.reports = []
    
    def print_performance_summary(self, summary: Dict):
        """Print formatted performance summary"""
        print("\n" + "="*60)
        print("📊 PERFORMANCE SUMMARY")
        print("="*60)
        
        print(f"\n🖥️  SYSTEM METRICS:")
        print(f"   Duration: {summary['duration_minutes']} minutes")
        print(f"   Sample Count: {summary['sample_count']}")
        
        print(f"\n💻 CPU USAGE:")
        print(f"   Average: {summary['cpu']['average']:.1f}%")
        print(f"   Min: {summary['cpu']['min']:.1f}%")
        print(f"   Max: {summary['cpu']['max']:.1f}%")
        print(f"   P95: {summary['cpu']['p95']:.1f}%")
        
        print(f"\n🧠 MEMORY USAGE:")
        print(f"   Average: {summary['memory']['average_percent']:.1f}% ({summary['memory']['average_mb']:.1f} MB)")
        print(f"   Min: {summary['memory']['min_percent']:.1f}%")
        print(f"   Max: {summary['memory']['max_percent']:.1f}% ({summary['memory']['max_mb']:.1f} MB)")
        
        print(f"\n⚙️  PROCESSES:")
        print(f"   Average Count: {summary['processes']['average_count']:.0f}")
        print(f"   Max Count: {summary['processes']['max_count']}")
    
    def print_benchmark_report(self, report: Dict):
        """Print formatted benchmark report"""
        print("\n" + "="*60)
        print("🚀 BENCHMARK REPORT")
        print("="*60)
        
        summary = report["summary"]
        print(f"\n📈 OVERALL STATISTICS:")
        print(f"   Total Tests: {summary['total_tests']}")
        print(f"   Total Requests: {summary['total_requests_estimated']}")
        print(f"   Average OPS: {summary['average_ops_per_second']:.2f}")
        print(f"   Average Response Time: {summary['average_response_time_ms']:.2f}ms")
        print(f"   Average Error Rate: {summary['average_error_rate_percent']:.2f}%")
        
        best = report["best_performers"]
        print(f"\n🏆 BEST PERFORMERS:")
        print(f"   Highest OPS: {best['highest_ops_per_second']['test_name']} ({best['highest_ops_per_second']['ops_per_second']:.2f} ops/sec)")
        print(f"   Fastest Response: {best['fastest_response_time']['test_name']} ({best['fastest_response_time']['response_time_ms']:.2f}ms)")
        
        worst = report["worst_performers"]
        print(f"\n⚠️  NEEDS ATTENTION:")
        print(f"   Lowest OPS: {worst['lowest_ops_per_second']['test_name']} ({worst['lowest_ops_per_second']['ops_per_second']:.2f} ops/sec)")
        print(f"   Slowest Response: {worst['slowest_response_time']['test_name']} ({worst['slowest_response_time']['response_time_ms']:.2f}ms)")
        
        print(f"\n📋 DETAILED RESULTS:")
        for result in report["detailed_results"]:
            print(f"   {result['test_name']}:")
            print(f"     OPS: {result['operations_per_second']:.2f}/sec")
            print(f"     Avg Response: {result['average_response_time_ms']:.2f}ms")
            print(f"     P95 Response: {result['p95_response_time_ms']:.2f}ms")
            print(f"     Error Rate: {result['error_rate_percent']:.2f}%")
    
    def save_report(self, data: Dict, filename: str):
        """Save report to JSON file"""
        with open(filename, 'w') as f:
            json.dump(data, f, indent=2, default=str)
        print(f"📄 Report saved to: {filename}")


async def main():
    """Main function for performance monitoring and benchmarking"""
    parser = argparse.ArgumentParser(description="MS5.0 Performance Monitoring and Benchmarking Tool")
    parser.add_argument("--mode", choices=["monitor", "benchmark", "both"], default="both",
                       help="Mode: monitor, benchmark, or both")
    parser.add_argument("--base-url", default="http://localhost:8000",
                       help="Base URL for API testing")
    parser.add_argument("--monitor-duration", type=int, default=5,
                       help="Monitoring duration in minutes")
    parser.add_argument("--benchmark-requests", type=int, default=50,
                       help="Number of requests per benchmark test")
    parser.add_argument("--concurrent-requests", type=int, default=5,
                       help="Number of concurrent requests")
    parser.add_argument("--output", default="performance_report.json",
                       help="Output report filename")
    
    args = parser.parse_args()
    
    print("🚀 MS5.0 Performance Monitoring and Benchmarking Tool")
    print(f"🌐 Base URL: {args.base_url}")
    
    reporter = PerformanceReporter()
    
    if args.mode in ["monitor", "both"]:
        print(f"\n🔍 Starting performance monitoring for {args.monitor_duration} minutes...")
        
        monitor = PerformanceMonitor()
        
        # Start monitoring in background
        monitor_task = asyncio.create_task(
            asyncio.to_thread(monitor.start_monitoring, 5)
        )
        
        # Wait for monitoring duration
        await asyncio.sleep(args.monitor_duration * 60)
        
        # Stop monitoring
        monitor.stop_monitoring()
        monitor_task.cancel()
        
        # Generate performance summary
        summary = monitor.get_performance_summary(args.monitor_duration)
        reporter.print_performance_summary(summary)
        
        # Save performance data
        performance_data = {
            "type": "performance_monitoring",
            "timestamp": datetime.now().isoformat(),
            "summary": summary,
            "raw_metrics": [asdict(m) for m in monitor.metrics_history[-100:]]  # Last 100 metrics
        }
        reporter.save_report(performance_data, "performance_monitoring.json")
    
    if args.mode in ["benchmark", "both"]:
        print(f"\n🧪 Starting benchmark tests...")
        
        benchmark = BenchmarkSuite(args.base_url)
        
        # Define test endpoints
        test_endpoints = [
            {"endpoint": "/api/v1/production/lines", "method": "GET"},
            {"endpoint": "/api/v1/oee/lines/test-line", "method": "GET"},
            {"endpoint": "/api/v1/andon/dashboard", "method": "GET"},
            {"endpoint": "/api/v1/dashboard/lines", "method": "GET"},
            {"endpoint": "/api/v1/production/lines", "method": "POST", 
             "json_data": {"line_code": "TEST", "name": "Test Line", "equipment_codes": ["EQ001"]}}
        ]
        
        # Run comprehensive benchmark
        results = await benchmark.run_comprehensive_benchmark(
            test_endpoints,
            {
                "concurrent_requests": args.concurrent_requests,
                "total_requests": args.benchmark_requests,
                "test_name_prefix": "MS5.0"
            }
        )
        
        # Generate benchmark report
        report = benchmark.generate_benchmark_report(results)
        reporter.print_benchmark_report(report)
        
        # Save benchmark data
        benchmark_data = {
            "type": "benchmark_results",
            "timestamp": datetime.now().isoformat(),
            "report": report
        }
        reporter.save_report(benchmark_data, "benchmark_results.json")
    
    # Generate combined report
    combined_data = {
        "type": "combined_performance_report",
        "timestamp": datetime.now().isoformat(),
        "configuration": vars(args),
        "performance_summary": summary if args.mode in ["monitor", "both"] else None,
        "benchmark_report": report if args.mode in ["benchmark", "both"] else None
    }
    
    reporter.save_report(combined_data, args.output)
    
    print(f"\n✅ Performance analysis complete!")
    print(f"📄 Reports saved to: {args.output}")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n⏹️  Performance monitoring stopped by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)
