import http from 'k6/http';
import { sleep, check } from 'k6';

// Fetch the URL from environment variables
const BASE_URL = __ENV.BASE_URL || 'http://localhost/';

// Test configuration
export let options = {
  stages: [
    { duration: '30s', target: 10 }, 
    { duration: '1m', target: 10 },  
    { duration: '30s', target: 0 },
  ],
};

export default function () {
  // Perform a GET request
  let res = http.get(BASE_URL);

  // Validate the response
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });

  sleep(1);
}
