function LJUser(textArea) {
    var editor_frame = $(textArea + '___Frame');
    if (!editor_frame) return;
    if (! FCKeditorAPI) return;
    var oEditor = FCKeditorAPI.GetInstance(textArea);
    if (! oEditor) return;

    var html = oEditor.GetXHTML(false);
    html = html.replace(/<\/lj>/, '');
    var regexp = /<lj user=['"](\w+?)['"] ?\/?>\s?(?:<\/lj>)?\s?/g;
    var userstr;
    var ljusers = [];
    var username;
    while ((ljusers = regexp.exec(html))) {
        username = ljusers[1];
        var postData = {
            "username" : username
        };
        var url = window.parent.LJVAR.siteroot + "/tools/endpoints/ljuser.bml";

        var gotError = function(err) {
            alert(err+' '+username);
            return;
        }

        var gotInfo = function (data) {
            if (data.error) {
                alert(data.error+' '+username);
                return;
            }
            if (!data.success) return;
            data.ljuser = data.ljuser.replace(/<span.+?class=['"]?ljuser['"]?.+?>/,'<div class="ljuser">');
            data.ljuser = data.ljuser.replace(/<\/span>/,'</div>');
            html = html.replace(data.userstr,data.ljuser+'&nbsp;');
            editor_frame.focus();
            oEditor.SetHTML(html,false);
            oEditor.Focus();
        }

        var opts = {
            "data": window.parent.HTTPReq.formEncoded(postData),
            "method": "POST",
            "url": url,
            "onError": gotError,
            "onData": gotInfo
        };

        window.parent.HTTPReq.getJSON(opts);
    }
}


function useRichText(textArea, statPrefix) {
    if ($("insobj")) {
        $("insobj").className = 'display_none';
    }
    if ($("jrich")) {
        $("jrich").className = 'display_none';
    }
    if ($("jplain")) {
        $("jplain").className = '';
    }

    var editor_frame = $(textArea + '___Frame');

    // Check for RTE already existing.  IE will show multiple iframes otherwise.
    if (!editor_frame) {
        var oFCKeditor = new FCKeditor(textArea);
        oFCKeditor.BasePath = statPrefix + "/fck/";
        oFCKeditor.Height = 350;
        oFCKeditor.ToolbarSet = "Update";
        if ($("event_format") && $("event_format").selectedIndex == 0) {
            $(textArea).value = $(textArea).value.replace(/\n/g, '<br />');
        }
        oFCKeditor.ReplaceTextarea();
    } else {
        if (! FCKeditorAPI) return;
        var oEditor = FCKeditorAPI.GetInstance(textArea);
        editor_frame.style.display = "block";
        $(textArea).style.display = "none";
        var editor_source = editor_frame.contentWindow.document.getElementById('eEditorArea');
        if ($("event_format") && $("event_format").selectedIndex == 0) {
            $(textArea).value = $(textArea).value.replace(/\n/g, '<br />');
        }
        oEditor.SetHTML($(textArea).value,false);

        // Allow RTE to use it's handler again so it's happy.
        var oForm = oEditor.LinkedField.form;
        DOM.addEventListener( oForm, 'submit', oEditor.UpdateLinkedField, true ) ;
        oForm.originalSubmit = oForm.submit;
        oForm.submit = oForm.SubmitReplacer;
    }

    // Need to pause here as it takes some time for the editor
    // to actually load within the browser before we can
    // access it.
    setTimeout("RTEAddClasses('" + textArea + "', '" + statPrefix + "')", 2000);

    $("switched_rte_on").value = '1';
    return false; // do not follow link
}

function RTEAddClasses(textArea, statPrefix) {
    var editor_frame = $(textArea + '___Frame');
    if (!editor_frame) return;
    if (! FCKeditorAPI) return;
    var oEditor = FCKeditorAPI.GetInstance(textArea);
    if (! oEditor) return;
    var html = oEditor.GetXHTML(false);

    var regex1 = /<lj-cut text=['"]?(.+?)['"]?>(.+?)<\/lj-cut>/;
    var regex2 = /<lj-cut>(.+?)<\/lj-cut>/;

    if (html.match(regex1)) {
        html = html.replace(regex1, '<div text="$1" class="ljcut">$2</div>');
    }
    if (html.match(regex2)) {
        html = html.replace(regex2, '<div text="$1" class="ljcut">$2</div>'); 
    }

    html = html.replace(/<lj-raw>([\w\s]+?)<\/lj-raw>/g, '<lj-raw class="ljraw">$1</lj-raw>');
    LJUser(textArea);
    html = html.replace(/<lj-template name=['"]video['"]>(\S+)<\/lj-template>/g, "<div url=\"$1\" class=\"ljvideo\"><img src='" + statPrefix + "/fck/editor/plugins/livejournal/ljvideo.gif' /></div>");
    editor_frame.focus();
    oEditor.Focus();
    oEditor.SetHTML(html);
}

function usePlainText(textArea) {
    if (! FCKeditorAPI) return;
    var oEditor = FCKeditorAPI.GetInstance(textArea);
    if (! oEditor) return;
    var editor_frame = $(textArea + '___Frame');
    var editor_source = editor_frame.contentWindow.document.getElementById('eEditorArea'); 

    var html = oEditor.GetXHTML(false);
    html = html.replace(/<div class=['"]ljcut['"] text=['"](.+?)['"]>(.+?)<\/div>/g, '<lj-cut text="$1">$2</lj-cut>');
    html = html.replace(/<div text=['"](.+?)['"] class=['"]ljcut['"]>(.+?)<\/div>/g, '<lj-cut text="$1">$2</lj-cut>');
    html = html.replace(/<div class=['"]ljuser['"]>.+?<b>(\w+?)<\/b><\/a><\/div>/g, '<lj user=\"$1\">');
    html = html.replace(/<div class=['"]ljvideo['"] url=['"](\S+)['"]><img.+?\/><\/div>/g, '<lj-template name=\"video\">$1</lj-template>');
    html = html.replace(/<div class=['"]ljvideo['"] url=['"](\S+)['"]><br \/><\/div>/g, '');
    if ($("event_format") && $("event_format").selectedIndex == 0) {
        html = html.replace(/\<br \/\>/g, '\n');
        html = html.replace(/\<p\>(.*?)\<\/p\>/g, '$1\n');
        html = html.replace(/&nbsp;/g, ' ');
    }
    editor_frame.focus();
    $(textArea).value = html;
    oEditor.Focus();

    if ($("insobj"))
        $("insobj").className = '';
    if ($("jrich"))
        $("jrich").className = '';
    if ($("jplain"))
        $("jplain").className = 'display_none';

    editor_frame.style.display = "none";
    $(textArea).style.display = "block";

    $("switched_rte_on").value = '0';

    // Remove onsubmit handler while in Plain text
    var oForm = oEditor.LinkedField.form;
    DOM.removeEventListener( oForm, 'submit', oEditor.UpdateLinkedField, true ) ;
    oForm.SubmitReplacer = oForm.submit;
    oForm.submit = oForm.originalSubmit;
    return false;
}

