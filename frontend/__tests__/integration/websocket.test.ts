/**
 * Integration tests for WebSocket service
 */

import { websocketService } from '../../src/services/websocket';

// Mock WebSocket
class MockWebSocket {
  public url: string;
  public readyState: number = WebSocket.CONNECTING;
  public onopen: ((event: Event) => void) | null = null;
  public onclose: ((event: CloseEvent) => void) | null = null;
  public onmessage: ((event: MessageEvent) => void) | null = null;
  public onerror: ((event: Event) => void) | null = null;

  constructor(url: string) {
    this.url = url;
    // Simulate connection after a short delay
    setTimeout(() => {
      this.readyState = WebSocket.OPEN;
      if (this.onopen) {
        this.onopen(new Event('open'));
      }
    }, 100);
  }

  send(data: string) {
    // Mock send implementation
  }

  close() {
    this.readyState = WebSocket.CLOSED;
    if (this.onclose) {
      this.onclose(new CloseEvent('close'));
    }
  }

  // Mock methods for testing
  simulateMessage(data: any) {
    if (this.onmessage) {
      this.onmessage(new MessageEvent('message', { data: JSON.stringify(data) }));
    }
  }

  simulateError() {
    if (this.onerror) {
      this.onerror(new Event('error'));
    }
  }
}

// Replace global WebSocket with mock
(global as any).WebSocket = MockWebSocket;

describe('WebSocket Service Integration', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Reset WebSocket service state
    websocketService.disconnect();
  });

  describe('Connection Management', () => {
    it('should connect to WebSocket', async () => {
      const connectPromise = websocketService.connect('ws://localhost:8000/ws');
      
      // Wait for connection to establish
      await new Promise(resolve => setTimeout(resolve, 150));
      
      expect(websocketService.isConnected()).toBe(true);
      
      await connectPromise;
    });

    it('should disconnect from WebSocket', () => {
      websocketService.connect('ws://localhost:8000/ws');
      
      websocketService.disconnect();
      
      expect(websocketService.isConnected()).toBe(false);
    });

    it('should handle connection errors', async () => {
      const mockWebSocket = new MockWebSocket('ws://localhost:8000/ws');
      const originalWebSocket = global.WebSocket;
      (global as any).WebSocket = jest.fn().mockImplementation(() => {
        setTimeout(() => {
          mockWebSocket.simulateError();
        }, 100);
        return mockWebSocket;
      });

      const errorPromise = new Promise((resolve) => {
        websocketService.on('error', resolve);
      });

      websocketService.connect('ws://localhost:8000/ws');
      
      await errorPromise;
      
      (global as any).WebSocket = originalWebSocket;
    });
  });

  describe('Message Handling', () => {
    beforeEach(async () => {
      await websocketService.connect('ws://localhost:8000/ws');
      await new Promise(resolve => setTimeout(resolve, 150));
    });

    it('should send messages', () => {
      const message = { type: 'test', data: 'test data' };
      const sendSpy = jest.spyOn(websocketService['ws']!, 'send');
      
      websocketService.send(message);
      
      expect(sendSpy).toHaveBeenCalledWith(JSON.stringify(message));
    });

    it('should receive messages', (done) => {
      const testMessage = { type: 'test', data: 'test data' };
      
      websocketService.on('message', (message) => {
        expect(message).toEqual(testMessage);
        done();
      });
      
      // Simulate receiving a message
      (websocketService['ws'] as any).simulateMessage(testMessage);
    });

    it('should handle different message types', (done) => {
      const messages = [
        { type: 'line_status_update', line_id: 'line-1', data: { status: 'running' } },
        { type: 'andon_event', data: { id: '1', event_type: 'fault' } },
        { type: 'oee_update', line_id: 'line-1', data: { oee: 0.85 } },
      ];
      
      let receivedCount = 0;
      
      websocketService.on('message', (message) => {
        expect(messages).toContainEqual(message);
        receivedCount++;
        
        if (receivedCount === messages.length) {
          done();
        }
      });
      
      // Simulate receiving messages
      messages.forEach(msg => {
        (websocketService['ws'] as any).simulateMessage(msg);
      });
    });
  });

  describe('Subscription Management', () => {
    beforeEach(async () => {
      await websocketService.connect('ws://localhost:8000/ws');
      await new Promise(resolve => setTimeout(resolve, 150));
    });

    it('should subscribe to line updates', () => {
      const sendSpy = jest.spyOn(websocketService['ws']!, 'send');
      
      websocketService.subscribe('line', 'line-001');
      
      expect(sendSpy).toHaveBeenCalledWith(JSON.stringify({
        type: 'subscribe',
        subscription_type: 'line',
        target: 'line-001'
      }));
    });

    it('should subscribe to Andon events', () => {
      const sendSpy = jest.spyOn(websocketService['ws']!, 'send');
      
      websocketService.subscribe('andon', 'line-001');
      
      expect(sendSpy).toHaveBeenCalledWith(JSON.stringify({
        type: 'subscribe',
        subscription_type: 'andon',
        target: 'line-001'
      }));
    });

    it('should subscribe to OEE updates', () => {
      const sendSpy = jest.spyOn(websocketService['ws']!, 'send');
      
      websocketService.subscribe('oee', 'line-001');
      
      expect(sendSpy).toHaveBeenCalledWith(JSON.stringify({
        type: 'subscribe',
        subscription_type: 'oee',
        target: 'line-001'
      }));
    });

    it('should unsubscribe from updates', () => {
      const sendSpy = jest.spyOn(websocketService['ws']!, 'send');
      
      websocketService.unsubscribe('line', 'line-001');
      
      expect(sendSpy).toHaveBeenCalledWith(JSON.stringify({
        type: 'unsubscribe',
        subscription_type: 'line',
        target: 'line-001'
      }));
    });
  });

  describe('Event Handling', () => {
    beforeEach(async () => {
      await websocketService.connect('ws://localhost:8000/ws');
      await new Promise(resolve => setTimeout(resolve, 150));
    });

    it('should handle line status updates', (done) => {
      websocketService.on('line_status_update', (data) => {
        expect(data.line_id).toBe('line-001');
        expect(data.data.status).toBe('running');
        done();
      });
      
      const message = {
        type: 'line_status_update',
        line_id: 'line-001',
        data: { status: 'running', speed: 95.0 }
      };
      
      (websocketService['ws'] as any).simulateMessage(message);
    });

    it('should handle Andon events', (done) => {
      websocketService.on('andon_event', (data) => {
        expect(data.data.event_type).toBe('fault');
        expect(data.data.priority).toBe('high');
        done();
      });
      
      const message = {
        type: 'andon_event',
        data: {
          id: '1',
          equipment_code: 'EQ-001',
          event_type: 'fault',
          priority: 'high',
          status: 'active'
        }
      };
      
      (websocketService['ws'] as any).simulateMessage(message);
    });

    it('should handle OEE updates', (done) => {
      websocketService.on('oee_update', (data) => {
        expect(data.line_id).toBe('line-001');
        expect(data.data.oee).toBe(0.85);
        expect(data.data.availability).toBe(0.9);
        done();
      });
      
      const message = {
        type: 'oee_update',
        line_id: 'line-001',
        data: {
          oee: 0.85,
          availability: 0.9,
          performance: 0.95,
          quality: 0.95
        }
      };
      
      (websocketService['ws'] as any).simulateMessage(message);
    });

    it('should handle job updates', (done) => {
      websocketService.on('job_update', (data) => {
        expect(data.job_id).toBe('job-001');
        expect(data.data.status).toBe('in_progress');
        done();
      });
      
      const message = {
        type: 'job_update',
        job_id: 'job-001',
        data: {
          id: 'job-001',
          status: 'in_progress',
          progress: 50
        }
      };
      
      (websocketService['ws'] as any).simulateMessage(message);
    });

    it('should handle escalation updates', (done) => {
      websocketService.on('escalation_update', (data) => {
        expect(data.escalation_id).toBe('esc-001');
        expect(data.data.status).toBe('escalated');
        done();
      });
      
      const message = {
        type: 'escalation_update',
        escalation_id: 'esc-001',
        data: {
          id: 'esc-001',
          event_id: 'event-001',
          escalation_level: 2,
          status: 'escalated'
        }
      };
      
      (websocketService['ws'] as any).simulateMessage(message);
    });

    it('should handle quality alerts', (done) => {
      websocketService.on('quality_alert', (data) => {
        expect(data.line_id).toBe('line-001');
        expect(data.data.parameter).toBe('temperature');
        expect(data.data.severity).toBe('warning');
        done();
      });
      
      const message = {
        type: 'quality_alert',
        line_id: 'line-001',
        data: {
          parameter: 'temperature',
          value: 85.5,
          threshold: 80.0,
          severity: 'warning'
        }
      };
      
      (websocketService['ws'] as any).simulateMessage(message);
    });

    it('should handle changeover events', (done) => {
      websocketService.on('changeover_event', (data) => {
        expect(data.data.line_id).toBe('line-001');
        expect(data.data.status).toBe('started');
        done();
      });
      
      const message = {
        type: 'changeover_event',
        data: {
          id: 'co-001',
          line_id: 'line-001',
          status: 'started',
          estimated_duration_minutes: 30
        }
      };
      
      (websocketService['ws'] as any).simulateMessage(message);
    });
  });

  describe('Error Handling', () => {
    beforeEach(async () => {
      await websocketService.connect('ws://localhost:8000/ws');
      await new Promise(resolve => setTimeout(resolve, 150));
    });

    it('should handle invalid JSON messages', (done) => {
      websocketService.on('error', (error) => {
        expect(error.message).toContain('Invalid JSON');
        done();
      });
      
      // Simulate invalid JSON message
      const mockWebSocket = websocketService['ws'] as any;
      if (mockWebSocket.onmessage) {
        mockWebSocket.onmessage(new MessageEvent('message', { data: 'invalid json' }));
      }
    });

    it('should handle connection errors', (done) => {
      websocketService.on('error', (error) => {
        expect(error).toBeDefined();
        done();
      });
      
      (websocketService['ws'] as any).simulateError();
    });

    it('should handle connection close', (done) => {
      websocketService.on('close', () => {
        expect(websocketService.isConnected()).toBe(false);
        done();
      });
      
      websocketService.disconnect();
    });
  });

  describe('Reconnection Logic', () => {
    it('should attempt reconnection on connection loss', async () => {
      await websocketService.connect('ws://localhost:8000/ws');
      await new Promise(resolve => setTimeout(resolve, 150));
      
      // Simulate connection loss
      websocketService.disconnect();
      
      // Attempt reconnection
      await websocketService.reconnect();
      await new Promise(resolve => setTimeout(resolve, 150));
      
      expect(websocketService.isConnected()).toBe(true);
    });

    it('should handle reconnection failures', async () => {
      // Mock WebSocket to always fail
      const originalWebSocket = global.WebSocket;
      (global as any).WebSocket = jest.fn().mockImplementation(() => {
        throw new Error('Connection failed');
      });
      
      try {
        await websocketService.connect('ws://invalid-url');
      } catch (error) {
        expect(error).toBeDefined();
      }
      
      (global as any).WebSocket = originalWebSocket;
    });
  });

  describe('Heartbeat Management', () => {
    beforeEach(async () => {
      await websocketService.connect('ws://localhost:8000/ws');
      await new Promise(resolve => setTimeout(resolve, 150));
    });

    it('should send heartbeat messages', () => {
      const sendSpy = jest.spyOn(websocketService['ws']!, 'send');
      
      websocketService.sendHeartbeat();
      
      expect(sendSpy).toHaveBeenCalledWith(JSON.stringify({
        type: 'heartbeat'
      }));
    });

    it('should handle heartbeat responses', (done) => {
      websocketService.on('heartbeat_response', (data) => {
        expect(data.timestamp).toBeDefined();
        done();
      });
      
      const message = {
        type: 'heartbeat_response',
        timestamp: new Date().toISOString()
      };
      
      (websocketService['ws'] as any).simulateMessage(message);
    });
  });
});
