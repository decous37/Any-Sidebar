import {MODELS} from '../shared/providers';
import type {PreferenceValues,ReasoningEffort} from '../shared/types';
import ThinkingPicker from '../ui/ThinkingPicker';
export default function ChromeThinkingPicker({prefs,disabled,onChange}:{prefs:PreferenceValues;disabled:boolean;onChange:(patch:Partial<PreferenceValues>)=>void}){const model=MODELS.find(m=>m.id===prefs.model);return <ThinkingPicker enabled={!!(prefs.thinkingEnabled&&model?.thinking)} effort={prefs.reasoningEffort} efforts={model?.reasoningEfforts??[]} disabled={disabled||!model?.thinking} onChange={value=>onChange(value==='off'?{thinkingEnabled:false}:{thinkingEnabled:true,reasoningEffort:value as ReasoningEffort})}/>;}
