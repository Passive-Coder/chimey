import {test} from 'node:test';
import assert from 'node:assert/strict';
import {makeServer,validateClip} from './server.mjs';
const token='test-token-with-at-least-24-characters';
const wav=()=>{const b=Buffer.alloc(32044);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(16000,24);b.writeUInt32LE(32000,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(b.length-44,40);return b;};
async function fixture(t,fetcher) {
 const server=makeServer({apiKey:'test-provider-key',token,fetcher});await new Promise(r=>server.listen(0,'127.0.0.1',r));t.after(()=>new Promise(r=>server.close(r)));
 const url=`http://127.0.0.1:${server.address().port}`;
 return async(path,body,headers={})=>fetch(url+path,{method:'POST',headers:{'content-type':'application/json',authorization:`Bearer ${token}`,...headers},body:JSON.stringify(body)});
}
test('clip validator rejects wrong sample rate, oversize and malformed audio',()=>{
 assert.equal(validateClip(wav().toString('base64')).length,32044);
 const wrong=wav();wrong.writeUInt32LE(48000,24);assert.throws(()=>validateClip(wrong.toString('base64')));
 assert.throws(()=>validateClip(Buffer.alloc(256046).toString('base64')));assert.throws(()=>validateClip('not audio'));
});
test('authentication and per-request consent prevent provider calls',async t=>{
 let calls=0;const request=await fixture(t,async()=>{calls++;throw Error();});
 assert.equal((await request('/analyze',{audio:wav().toString('base64')})).status,400);
 assert.equal((await request('/research',{consent:true,description:'beep'},{authorization:'Bearer wrong'})).status,401);
 assert.equal((await request('/research',{consent:true,description:'beep'},{origin:'https://unapproved.example'})).status,403);assert.equal(calls,0);
});
test('audio analysis forwards real audio, disables provider storage and cannot execute rules',async t=>{
 let upstream;const request=await fixture(t,async(url,options)=>{assert.match(url,/\/interactions$/);upstream=JSON.parse(options.body);return Response.json({steps:[{type:'model_output',content:[{type:'text',text:'A possible electronic beep.'}]}]});});
 const response=await request('/analyze',{consent:true,audio:wav().toString('base64')});assert.equal(response.status,200);
 assert.equal(upstream.input[0].mime_type,'audio/wav');assert.equal(upstream.input[0].data,wav().toString('base64'));assert.equal(upstream.store,false);assert.equal(upstream.tools,undefined);
 const result=await response.json();assert.equal(result.kind,'explanation');assert.equal(result.confirmed,false);assert.deepEqual(result.citations,[]);
});
test('text research searches independently and preserves safe source attribution',async t=>{
 let upstream;const request=await fixture(t,async(_,options)=>{upstream=JSON.parse(options.body);return Response.json({steps:[{type:'model_output',content:[{type:'text',text:'A manual describes a tone.',annotations:[{type:'url_citation',title:'Manual',url:'https://example.com/manual',start_index:0,end_index:24},{type:'url_citation',url:'javascript:alert(1)'}]}]},{type:'google_search_result',result:[{search_suggestions:'<div>Search suggestions</div>'}]}]});});
 const response=await request('/research',{consent:true,description:'Repeating timer tone'});assert.equal(response.status,200);assert.deepEqual(upstream.tools,[{type:'google_search'}]);assert.equal(upstream.input.some(v=>v.type==='audio'),false);
 const body=await response.json();assert.equal(body.citations.length,1);assert.equal(body.citations[0].url,'https://example.com/manual');assert.equal(body.searchSuggestions.length,1);
});
test('provider failures remain uncertain and return no action command',async t=>{
 const request=await fixture(t,async()=>Response.json({error:'provider failure'},{status:503}));const result=await request('/research',{consent:true,description:'beep'});assert.equal(result.status,502);assert.match((await result.json()).error,/No sound rule/);
});
