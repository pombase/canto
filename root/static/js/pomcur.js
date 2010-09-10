$(document).ready(function() {
  $(".sect .sect-title").each(function(i) {
    $(this).click(function() {
      $(this).next().toggle();
      $(this).toggleClass('undisclosed-title');
      $(this).toggleClass('disclosed-title');
      return false;
        }
        );
    if ($(this).is(".undisclosed-title")) {
        $(this).next().hide();
    } else {
        $(this).next().show();
    }
  })
});

$(function() {
    var cache = {};
    $( "#ontology-term-entry" ).autocomplete({
        minLength: 0,
        source: ontology_complete_url,
        focus: function(event, ui) {
            $('#ontology-term-entry').val(ui.item.match);
            return false;
        },
        select: function(event, ui) {
            $('#ontology-term-entry').val(ui.item.match);
            return false;
        }
    })
    .data( "autocomplete" )._renderItem = function( ul, item ) {
        return $( "<li></li>" )
            .data( "item.autocomplete", item )
            .append( "<a>" + item.match + "<br>" + item.description + "</a>" )
            .appendTo( ul );
    };
});
