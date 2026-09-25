import test from 'node:test';
import assert from 'node:assert/strict';
import { loadGlossary, splitTerms, termSlug, termHtml } from '../remark-terms.mjs';
import { parseQuiz } from '../remark-quiz.mjs';

test('the glossary table is read into terms with aliases and plain-text definitions', () => {
  const g = loadGlossary();
  assert.ok(g['Ang']); assert.match(g['Ang'].definition, /page/i);
  assert.ok(g['Salok'] && g['Pauri'], 'a "Salok / Pauri" row registers both names');
  assert.ok(!/[*`\[]/.test(g['comp_id'].definition));
  assert.equal(termSlug('Salok / Pauri'), 'term-salok-pauri');
  assert.equal(termSlug('ੴ'), 'term-ੴ');
});

test('[[Term]] and [[Term|shown]] become hover-cards; unknown terms fail', () => {
  const g = { Ang: { term: 'Ang', definition: 'A page.', aliases: ['Ang'] } };
  const nodes = splitTerms('one [[Ang]] and [[Ang|the Ang]] here', g);
  assert.equal(nodes.length, 5);
  assert.equal(nodes[1].type, 'html'); assert.match(nodes[1].value, /<sggs-term data-term="Ang" data-definition="A page\." data-href="\/glossary\/#term-ang">Ang<\/sggs-term>/);
  assert.match(nodes[3].value, />the Ang<\/sggs-term>/);
  assert.equal(splitTerms('no terms here', g), null);
  assert.throws(() => splitTerms('[[Nope]]', g), /not a glossary term/);
  assert.match(termHtml('a<b', g.Ang), /a&lt;b/);
});

test('a quiz fence parses, and malformed quizzes fail the build', () => {
  const qs = parseQuiz('Q: How many Angs?\n- 1430 ✓ — the last is Raagmala\n- 1483 — the PDF page count\nQ: Two?\n- yes ✓\n- no');
  assert.equal(qs.length, 2); assert.equal(qs[0].answers[0].right, true); assert.equal(qs[0].answers[0].why, 'the last is Raagmala'); assert.equal(qs[0].answers[1].right, false);
  assert.throws(() => parseQuiz('Q: x\n- a\n- b'), /exactly one ✓/);
  assert.throws(() => parseQuiz('Q: x\n- a ✓'), /at least two/);
  assert.throws(() => parseQuiz('- a ✓'), /not understood/);
});
