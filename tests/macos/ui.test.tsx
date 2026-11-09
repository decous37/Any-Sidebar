import {render,fireEvent,screen,cleanup,waitFor} from '@testing-library/react';
import {afterEach,it,expect,vi} from 'vitest';
import App from '../../apps/macos/web/App';
import {MacStore} from '../../apps/macos/web/store';
import {NativeBridge} from '../../apps/macos/web/bridge';
import {bootstrap} from './fixtures';
import {ComposerInput} from '../../src/ui/ComposerView';
import MarkdownMessage from '../../src/ui/MarkdownMessage';
import {ClipboardProvider} from '../../src/ui/ClipboardProvider';
afterEach(cleanup);
it('shows a Key notice before opening settings and retains question',async()=>{const state=bootstrap();state.runtime.currentTask!.draft.prompt='解释这一段';const post=vi.fn(async()=>({ok:true,data:structuredClone(state)})),store=new MacStore(new NativeBridge(post));store.accept(state);render(<App store={store}/>);fireEvent.click(screen.getByLabelText('发送问题'));expect(await screen.findByRole('dialog',{name:'请先填写 API Key'})).toBeTruthy();expect(post.mock.calls.length).toBe(1);fireEvent.click(screen.getByText('确定'));await waitFor(()=>expect(document.activeElement).toBe(screen.getByLabelText('API Key')));expect(store.input(state.runtime.activeTaskId!)).toBe('解释这一段');});
it('does not send during IME composition',()=>{const send=vi.fn();render(<ComposerInput value="问题" active={false} onChange={()=>{}} onSend={send}/>);const input=screen.getByLabelText('问题');fireEvent.compositionStart(input);fireEvent.keyDown(input,{key:'Enter'});expect(send).not.toHaveBeenCalled();fireEvent.compositionEnd(input);fireEvent.keyDown(input,{key:'Enter',shiftKey:true});expect(send).not.toHaveBeenCalled();});
it('uses the native clipboard adapter and never loads remote answer images',async()=>{const write=vi.fn(async()=>{});const {container}=render(<ClipboardProvider write={write}><MarkdownMessage answer={'回答 ![tracker](https://example.com/x.png)\n\n<script>alert(1)</script>\n\n```js\nconst n = 1;\n```'}/></ClipboardProvider>);expect(container.querySelector('img,script')).toBeNull();fireEvent.click(screen.getByLabelText('复制代码'));await waitFor(()=>expect(write).toHaveBeenCalledWith('const n = 1;'));});

it('allows image-only Enter without changing Chrome empty-input behavior',()=>{const send=vi.fn();const view=render(<ComposerInput value="" active={false} allowEmpty onChange={()=>{}} onSend={send}/>);fireEvent.keyDown(screen.getByLabelText('问题'),{key:'Enter'});expect(send).toHaveBeenCalledTimes(1);view.rerender(<ComposerInput value="" active={false} onChange={()=>{}} onSend={send}/>);fireEvent.keyDown(screen.getByLabelText('问题'),{key:'Enter'});expect(send).toHaveBeenCalledTimes(1);});
