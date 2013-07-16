$(function() {
    // this variable is just so we can map the label to its input
    // it is not the same as the file id
    var _uiCounter = 0;

    var _uploadInProgress = false;
    var _metadataInProgress = false;

    // hide the upload button, we'll have another one for saving descriptions
    $(".upload-form input[type=submit], .upload-form .log").hide();

    var _doEditRequest = function( form_fields ) {
        // form fields are the actual input fields
        // we need to extract them into the form of:
        // {
        //     mediaid: { propname => value, propname => value },
        //     mediaid: { propname => vaule, propname => value }
        // }

        var data = {};
        $.each( form_fields, function( i, form_field ) {
            var file_id = form_field.getAttribute("data-file-id");

            if ( ! data[file_id] )
                data[file_id] = {};

            data[file_id][form_field.name] = form_field.value;
        });

        $.ajax( Site.siteroot + '/api/v1/file/edit', {
            'type'      : 'POST',
            'dataType'  : 'json',
            'contentType': 'application/json',

            'data'      : JSON.stringify( data )
        } )
        .done(function() {
            if ( ! _metadataInProgress ) {
                $(".upload-form .log")
                    .addClass( "success" )
                    .removeClass( "alert" )
                    .text( "Your descriptions have been saved." )
                    .fadeIn().delay(3000).fadeOut();
                $(".upload-form input[type=submit]").val(function() {
                    return $(this).data("original-text");
                });
            }
        })
        .fail(function(jqXHR) {
            var response = JSON.parse(jqXHR.responseText);
            $(".upload-form .log")
                .addClass( "alert" )
                .removeClass( "success" )
                .text( "Unable to save: " + response.error )
                .fadeIn();
            $(".upload-form input[type=submit]").val(function() {
                    return $(this).data("original-text");
            });
        })
    };

    $(".upload-form-file-inputs")
        .find('input[type=file]')
            .attr( 'multiple', 'multiple' )
        .end()
        .find('.row')
            .append('<div class="large-12 columns"><div class="drop_zone">or drop images here</div></div>')
        .end()
    .fileupload({
        dataType: 'json',
        url: Site.siteroot + '/api/v1/file/new',

        autoUpload: false,

        previewMaxWidth: 800,
        previewMaxHeight: 800
    })
    .on( 'fileuploadadd', function(e, data) {
        var $output = $(".upload-form-preview ul");
        for ( var i = 0, f; f = data.files[i]; i++ ) {
            if ( f.type && f.type.indexOf( 'image') !== 0 ) return;

            // show the file preview and let the user upload metadata
            data.context = $($('#template-file-metadata').html())
                .appendTo( $output );

            data.context
                .find("label").attr( "for", function() {
                    return $(this).data("for-name") + _uiCounter;
                }).end()
                .find(":input").attr( "id", function() {
                    return this.name + _uiCounter;
                })

            _uiCounter++;

            data.formData = {};
            data.submit();
        }

        // and then add a button to save metadata
        $(".upload-form input[type=submit]")
            .val( "Save Descriptions" ).show()
            .click(function() {
                var $this = $(this);
                if ( ! $this.data("original-text" ) ) {
                    $this.data( "original-text", $this.val())
                }
                $this.val( "Saving..." );
            });
    })
    .on( 'fileuploaddone', function( e, data ) {
        var response = data.result;

        if ( response.success ) {
            var file_id = response.result.id;

            data.context
                // update the form field names to use this image id
                .find(":input").attr( "data-file-id", function(i, name){
                    return file_id;
                })
                .end()
                .find(".progress").toggleClass( "secondary success" );
        } else {
            $(data.context).trigger( "uploaderror", [ { error : data.error } ] );
        }
    })
    .on( 'fileuploadfail', function(e, data) {
        var responseText;
        if ( data.jqXHR && data.jqXHR.responseText ) {
            var response = JSON.parse(data.jqXHR.responseText);
            responseText = response.error;
        }
        if ( ! responseText ) {
            responseText = data.errorThrown;
        }

        $(data.context).trigger( "uploaderror", [ { error: responseText } ] );
    })
    .on( 'fileuploadprocessalways', function( e, data ) {
        var index = data.index;
        var $node = data.context;

        if ( ! $node ) return;

        $node.find( ".image-preview").prepend( data.files[index].preview );
    })
    .on( 'fileuploadprogress', function (e, data) {
       var progress = parseInt(data.loaded / data.total * 100, 10);
       data.context.find( ".meter" ).css( 'width', progress + '%' );
    })
    .on( 'fileuploadstart', function(data) {
        _uploadInProgress = true;
    })
    // now make sure we upload the metadata in case we tried to submit metadata
    // before we got an id back (from the file upload)
    .on( 'fileuploadstop', function(data) {
        if ( _metadataInProgress ) {
            // now submit all form fields...
            _doEditRequest( $('.upload-form :input') );
            _metadataInProgress = false;
        }

        _uploadInProgress = false;
    })

    $('.upload-form').submit(function(e) {
        e.preventDefault();
        e.stopPropagation();

        var formFields = $(':input[data-file-id]', this);
        if ( formFields.length < $("input[type=text], select", this).length ) {
            _metadataInProgress = true;
        }

        _doEditRequest( formFields );
    });

    // error handler when uploading an image
    $(".upload-form-preview ul").on( 'uploaderror', function(e, data) {
        $(e.target)
            // error message
            .find( ".progress.success" )
                .replaceWith( "<small class='error' role='alert'>" + data.error + "</small>")
            .end()
            // dim text fields (don't actually disable though, may still want the text inside)
            .find( ":input" )
                .addClass( "disabled" )
                .attr( "aria-invalid", true );

    });

    $(window).on('beforeunload', function(e) {
        if(_uploadInProgress || _metadataInProgress) {
            return "Your files haven't finished uploading yet.";
        }
    });
});;
