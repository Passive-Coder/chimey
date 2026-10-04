// Read the shipped LiteRT FlatBuffer tensor contract without conversion tools.
import {readFileSync} from 'node:fs';
const b=readFileSync(process.argv[2]);
const field=(t,n)=>{const v=t-b.readInt32LE(t),s=b.readUInt16LE(v);return 4+2*n<s ? b.readUInt16LE(v+4+2*n):0;};
const at=(t,n)=>{const o=field(t,n);return o?t+o:0;};
const ref=p=>p? p+b.readUInt32LE(p):0;
const vec=(t,n)=>{const p=ref(at(t,n));return p?Array.from({length:b.readUInt32LE(p)},(_,i)=>p+4+i*4):[];};
const str=p=>{p=ref(p);return p?b.toString('utf8',p+4,p+4+b.readUInt32LE(p)):'';};
const m=b.readUInt32LE(0),g=ref(vec(m,2)[0]);
const tensors=vec(g,0).map(ref).map((t,i)=>({index:i,name:str(at(t,3)),shape:vec(t,0).map(p=>b.readInt32LE(p)),type:at(t,1)?b.readUInt8(at(t,1)):0}));
const inputs=vec(g,1).map(p=>b.readInt32LE(p)),outputs=vec(g,2).map(p=>b.readInt32LE(p));
console.log(JSON.stringify({inputs:inputs.map(i=>tensors[i]),outputs:outputs.map(i=>tensors[i]),embeddingCandidates:tensors.filter(t=>t.shape.includes(1024))},null,2));
