import type {SessionView,TurnView,AssistantQuote} from '../shared/types';
import {terminal} from '../shared/types';
import ConversationView from '../ui/ConversationView';
import type {ConversationTurn} from '../ui/view-models';
interface Props {view:SessionView;onRetry:(t:TurnView)=>void;onRegenerate:(t:TurnView)=>void;onRestore:(t:TurnView)=>void;onOlder:()=>void;onQuote:(quote:AssistantQuote,followup?:boolean)=>void;onClearQuote:(id:string)=>void;busy:boolean}
export default function MessageList({view,onRetry,onRegenerate,onRestore,onOlder,onQuote,onClearQuote,busy}:Props){
 const turns:ConversationTurn[]=view.turns.map((t,index)=>({id:t.turn.id,requestId:t.reply.displayRequestId??t.reply.requestId,question:t.turn.question,quotes:[...t.turn.quotes.map(q=>({id:q.id,text:q.text,label:'网页引用'})),...(t.turn.assistantQuote?[{...t.turn.assistantQuote,label:'AI 回答'}]:[])],answer:t.reply.answer,reasoning:t.reply.reasoning,status:t.reply.status,error:t.reply.restoredAnswer?'重新生成未完成，已保留原回答。':t.reply.error?.message,canRegenerate:index===view.turns.length-1&&t.reply.status==='complete',canRetry:index===view.turns.length-1&&terminal(t.reply.status)&&t.reply.status!=='complete'&&t.reply.retryable}));
 const original=(t:ConversationTurn)=>view.turns.find(v=>v.turn.id===t.id)!;
 return <ConversationView taskId={view.session.id} turns={turns} active={busy||!!view.session.activeRequestId} quote={view.draft.assistantQuote} onQuote={(t,text,followup)=>onQuote({id:crypto.randomUUID(),sourceTurnId:t.id,sourceRequestId:t.requestId,text,selectedAt:Date.now()},followup)} onClearQuote={onClearQuote} onRetry={t=>onRetry(original(t))} onRegenerate={t=>onRegenerate(original(t))} onRestore={t=>onRestore(original(t))} onOlder={onOlder} hasOlder={view.nextBeforeOrder!==null}/>;
}
