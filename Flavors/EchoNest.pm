package Flavors::EchoNest;

use strict;

use Flavors::Util;

sub ModalHTML {
    my $html = sprintf(qq{
        <div id="echo-nest" class="modal" data-api-key="%s">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <div class="pull-right">
                            <a href="http://the.echonest.com/" class="img-link" target="_blank">
                                <img src="images/echo_nest.png" />
                            </a>
                        </div>
                        <h4 class="modal-title"></h4>
                    </div>
                    <div class="modal-body">
                        <div class="alert alert-danger hide"></div>
                        <table class="table table-striped table-hover">
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    }, Flavors::Util::Config->{echo_nest_api_key});

    $html .= qq{
        <script type="text/template" id="echo-nest-disambiguation-row">
            <tr class="clickable disambiguation" data-id="<%= id %>">
                <td><%= artist_name %></td>
                <td><%= title %></td>
                <td><%= id %></td>
            </tr>
        </script>
        <script type="text/template" id="echo-nest-summary-row">
            <% for (var i in pairs) { %>
                <tr>
                    <td><%= pairs[i].key %></td>
                    <td><%= pairs[i].value %></td>
                </tr>
            <% } %>
        </script>
    };

    return $html;
}

1;
