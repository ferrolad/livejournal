(function($) {

function approve(e) {
    e.preventDefault();

    var id = $(this.parentNode).data( 'dw-screened' );
    var y_pos = $("#approveans").val( id )
        .offset().top;

    scrollTo( 0, y_pos );
}

$.supportform = {
    init: function() {
        $( "select[name=faqid]" ).after(" <a href='#' id='faqlink'>View FAQ</a>").change( function() {
            var $link = $("#faqlink");
            if ( this.value === "0" ) {
                $link.hide();
            } else {
                $link.show().attr( "href", 'faqbrowse?faqid=' + this.value + '&view=full' );
            }
        } ).triggerHandler( "change" );


        $( "#internaltype" ).change( function(e) {
            $( "#bounce_email" ).toggle( this.value == "bounce" );
        }).triggerHandler( "change" );


        $( "select, input" ).filter( "[name=changecat], [name=touch], [name=untouch], [name=approveans]" )
            .change( function() {
                $.supportform.makeInternal();
            });


        $( "#changesum" ).click(function() {
            if ( this.checked ) $.supportform.makeInternal();
        });

        $( "input[name=summary]").change( function(){
            $( "#changesum" ).attr( "checked", "checked" );
            $.supportform.makeInternal();
        } );

        $(".approve").append($("<a href='#''>approve this answer</a>").click(approve));
    },

    makeInternal: function() {
        $( "#internaltype" ).val( "internal" ).triggerHandler( "change" );
    }
};

})(jQuery);

jQuery(document).ready(function($) {
    $.supportform.init();
});
