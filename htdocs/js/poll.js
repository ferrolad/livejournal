/* Poll structure:
	name: string
	whovote: all | friends
	whoview: all | friends | none
	questions: {[
		name: string
		type: check | drop | radio | scale | text
		size: string      // if type is text
		maxlength: string // if type is text
		from: string // if type is scale
		to: string   // if type is scale
		by: string   // if type is scale
		answers: [string, ...] // if type is check | drop | radio
	], ...}
*/

// Poll Object Constructor
function Poll(doc, q_num)
{
	if (typeof doc == 'string') {
		var ljtags = jQuery(doc);
		this.name = ljtags.attr('name');
		this.whovote = ljtags.attr('whovote');
		this.whoview = ljtags.attr('whoview');
		this.questions = [];
		
		ljtags.find('lj-pq').each(function(i, pq)
		{
			var pq = jQuery(pq),
				name = pq.html().match(/^\s*(.*?)\s*(?:<lj-pi>|$)/),
				question = {
					name: (name && name[1]) || '',
					type: pq.attr('type'),
					answers: []
				};
			
			if (!/^check|drop|radio|scale|text$/.test(question.type)) {
				return;
			}
			
			if (/^check|drop|radio$/.test(question.type)) {
				pq.find('lj-pi').each(function()
				{
					question.answers.push(jQuery(this).html())
				});
			}
			if (question.type == 'text') {
				question.size = pq.attr('size');
				question.maxlength = pq.attr('maxlength');
			}
			if (question.type == 'scale') {
				question.from = pq.attr('from');
				question.to = pq.attr('to');
				question.by = pq.attr('by');
			}
			this.questions.push(question);
		}.bind(this));
	} else {
		var form = doc.poll;
		this.name = form.name.value || '';
		this.whovote = jQuery(form.whovote).filter(':checked').val();
		this.whoview = jQuery(form.whoview).filter(':checked').val();
		// Array of Questions and Answers
		// A single poll can have multiple questions
		// Each question can have one or several answers
		this.questions = [];
		for (var i=0; i<q_num; i++) {
			this.questions[i] = new Answer(doc, i);
		}
	}
}

// Poll method to generate HTML for RTE
Poll.prototype.outputHTML = function()
{
	var html = '<form action="#" class="ljpoll" data="'+escape(this.outputLJtags())+'"><b>Poll #xxxx</b>';
	
	if (this.name) html += ' <i>'+this.name+'</i>';
	html += '<br/>Open to: '+
			'<b>'+this.whovote+'</b>, results viewable to: '+
			'<b>'+this.whoview+'</b>';
	for (var i=0; i<this.questions.length; i++) {
		html += '<br/><p>'+this.questions[i].name+'</p>'+
				'<p style="margin:0 0 10px 40px">';
		if (this.questions[i].type == 'radio' || this.questions[i].type == 'check') {
			var type = this.questions[i].type == 'check' ? 'checkbox' : this.questions[i].type;
			for (var j = 0;  j < this.questions[i].answers.length; j++) {
				html += '<input type="'+type+'">'+this.questions[i].answers[j]+'<br/>';
			}
		} else if (this.questions[i].type == 'drop') {
			html += '<select name="select_'+i+'">'+
					'<option value=""></option>';
			for (var j = 0; j < this.questions[i].answers.length; j++) {
				html += '<option value="">' + this.questions[i].answers[j] + '</option>';
			}
			html += '</select>';
		} else if (this.questions[i].type == 'text') {
			html += '<input maxlength="' + this.questions[i].maxlength + '" size="' + this.questions[i].size + '" type="text"/>';
		} else if (this.questions[i].type == 'scale') {
			html += '<table><tbody><tr align="center" valign="top">'
			var from = Number(this.questions[i].from),
				to   = Number(this.questions[i].to),
				by   = Number(this.questions[i].by);
			for (var j = from; j <= to; j = j + by) {
				html += '<td><input type="radio"/><br/>' + j + '</td>';
			}
			html += '</tr></tbody></table>';
		}
		html += '</p>';
	}
	
	html += '<input type="submit" disabled="disabled" value="Submit Poll"/></form>';
	return html;
}

// Poll method to generate LJ Poll tags
Poll.prototype.outputLJtags = function()
{
	var tags = '';
	
	tags += '<lj-poll name="'+this.name+'" whovote="'+this.whovote+'" whoview="'+this.whoview+'">\n';
	
	for (var i = 0; i < this.questions.length; i++) {
		var extrargs = '';
		if (this.questions[i].type == 'text') {
			extrargs = ' size="'+this.questions[i].size+'"'+
						' maxlength="'+this.questions[i].maxlength+'"';
		} else if (this.questions[i].type == 'scale') {
			extrargs = ' from="'+this.questions[i].from+'"'+
						' to="'+this.questions[i].to+'"'+
						' by="'+this.questions[i].by+'"';
		}
		tags += ' <lj-pq type="'+this.questions[i].type+'"'+extrargs+'>\n'+
				' ' + this.questions[i].name + '\n';
		if (/^check|drop|radio$/.test(this.questions[i].type)) {
			for (var j = 0; j < this.questions[i].answers.length; j++) {
				tags += '  <lj-pi>' + this.questions[i].answers[j] + '</lj-pi>\n';
			}
		}
		tags += ' </lj-pq>\n';
	}
	
	tags += '</lj-poll>';
	
	return tags;
}

Poll.callRichTextEditor = function() {
    var oEditor = FCKeditorAPI.GetInstance('draft');
    oEditor.Commands.GetCommand('LJPollLink').Execute();
}

// Answer Object Constructor
function Answer(doc, id)
{
	var form = doc.poll;
	this.name = form['question_'+id].value;
	this.type = jQuery(form['type_'+id]).val();
	
	if (/^check|drop|radio$/.test(this.type)) {
		this.answers = [];
		
		jQuery('#QandA_'+id+' input[name^="answer_'+id+'_"][value!=""]', form).each(function(i, node)
		{
			this.answers.push(node.value);
		}.bind(this));
	} else if (this.type == 'text') {
		this.size = form['pq_'+id+'_size'].value;
		this.maxlength = form['pq_'+id+'_maxlength'].value;
	} else if (this.type == 'scale') {
		this.from = form['pq_'+id+'_from'].value;
		this.to   = form['pq_'+id+'_to'].value;
		this.by   = form['pq_'+id+'_by'].value;
	}
}
