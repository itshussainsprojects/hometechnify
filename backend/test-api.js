const http = require('http');

const options = {
    hostname: '192.168.18.71',
    port: 3000,
    path: '/api/categories',
    method: 'GET',
    headers: {
        'Authorization': 'Bearer test-token-123'
    }
};

const req = http.request(options, (res) => {
    console.log(`STATUS: ${res.statusCode}`);
    res.setEncoding('utf8');
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
        console.log('BODY: ' + data);
    });
});

req.on('error', (e) => {
    console.error(`problem with request: ${e.message}`);
});

req.end();
